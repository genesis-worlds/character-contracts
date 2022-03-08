/* eslint-disable no-await-in-loop */
import { ethers } from "hardhat";
import { solidity } from "ethereum-waffle";
import chai from 'chai';
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { Character, MockErc20, MockToken } from "../typechain";
import { setNextBlockTimestamp, getLatestBlockTimestamp, mineBlock } from "../helper/utils";
import { deployContract } from "../helper/deployer";

chai.use(solidity);
const { expect } = chai;

describe('Character Airdrop', () => {
    const totalSupply = ethers.utils.parseUnits("100000000", 18);

    let genesis: MockErc20;
    let game: MockToken;
    let character: Character;
    let owner: SignerWithAddress;
    let alice: SignerWithAddress;
    let bob: SignerWithAddress;
    let feeReceiver: SignerWithAddress;
    let approvedContract: SignerWithAddress;

    const priceInGenesis = ethers.utils.parseUnits("100", 18);
    const priceInGame = ethers.utils.parseUnits("1000", 18);
    const priceInMatic = ethers.utils.parseUnits("1000", 18);

    before(async () => {
        [owner, alice, bob, feeReceiver, approvedContract] = await ethers.getSigners();
    });

    beforeEach(async () => {
        game = <MockToken>await deployContract("mockToken");
        genesis = <MockErc20>await deployContract("MockERC20", "Genesis token", "Gen", totalSupply);
        character = <Character>await deployContract("Character", game.address, genesis.address, feeReceiver.address);

        await character.setPriceInGame(priceInGame);
        await character.setPriceInGenesis(priceInGenesis);
        await character.setPriceInMatic(priceInMatic);

        await game.transfer(alice.address, totalSupply.div(10));
        await game.transfer(bob.address, totalSupply.div(10));
        await genesis.transfer(alice.address, totalSupply.div(10));
        await genesis.transfer(bob.address, totalSupply.div(10));

        await game.updateLocalContract(character.address, true);

        await character.grantRole(await character.APPROVED_CONTRACT(), approvedContract.address);
    });

    describe("Security", () => {
        it("setUniswapRouter", async () => {
            await expect(character.connect(alice).setUniswapRouter(ethers.constants.AddressZero)).to.be.reverted;
            await character.setUniswapRouter(ethers.constants.AddressZero);
        });

        it("setFeeReceiver", async () => {
            await expect(character.connect(alice).setFeeReceiver(ethers.constants.AddressZero)).to.be.reverted;
            await character.setFeeReceiver(ethers.constants.AddressZero);
        });

        it("setBaseURI", async () => {
            await expect(character.connect(alice).setBaseURI("https://new.base.uri")).to.be.reverted;
            await character.setBaseURI("https://new.base.uri");
        });

        it("setPriceInGenesis", async () => {
            await expect(character.connect(alice).setPriceInGenesis(10)).to.be.reverted;
            await character.setPriceInGenesis(10);
        });

        it("setPriceInGame", async () => {
            await expect(character.connect(alice).setPriceInGame(10)).to.be.reverted;
            await character.setPriceInGame(10);
        });

        it("setPriceInMatic", async () => {
            await expect(character.connect(alice).setPriceInMatic(10)).to.be.reverted;
            await character.setPriceInMatic(10);
        });
    });

    describe("buyNFT", () => {
        it("Get one nft using game", async () => {
            await game.connect(alice).approve(character.address, ethers.constants.MaxUint256);
            const nftCount0 = await character.balanceOf(alice.address);
            const balance0 = await game.balanceOf(alice.address);
            await character.connect(alice).buyNftWithGAME();
            const nftCount1 = await character.balanceOf(alice.address);
            const balance1 = await game.balanceOf(alice.address);
            expect(nftCount1.sub(nftCount0)).to.be.equal(1);
            expect(balance0.sub(balance1)).to.be.equal(priceInGame);
        });

        it("Get one nft with GENESIS", async () => {
            await genesis.connect(alice).approve(character.address, ethers.constants.MaxUint256);
            const nftCount0 = await character.balanceOf(alice.address);
            const balance0 = await genesis.balanceOf(alice.address);
            await character.connect(alice).buyNftWithGENESIS();
            const nftCount1 = await character.balanceOf(alice.address);
            const balance1 = await genesis.balanceOf(alice.address);
            expect(nftCount1.sub(nftCount0)).to.be.equal(1);
            expect(balance0.sub(balance1)).to.be.equal(priceInGenesis);
        });

        it("Get one nft with MATIC", async () => {
            const nftCount0 = await character.balanceOf(alice.address);
            const balance0 = await alice.getBalance();
            const tx = await character.connect(alice).buyNftWithMatic({ value: priceInMatic });
            const receipt = await tx.wait();
            const nftCount1 = await character.balanceOf(alice.address);
            const balance1 = await alice.getBalance();
            expect(nftCount1.sub(nftCount0)).to.be.equal(1);
            expect(balance0.sub(balance1)).to.be.equal(priceInMatic.add(receipt.gasUsed.mul(tx.gasPrice)));
        });
    });

    describe("Level up", () => {
        const levels = 1;
        const statsPlus = [1, 1, 1, 1, 1, 1, 1];
        it("levelUp with permission", async () => {
            const tokenId = 1;
            await genesis.connect(alice).approve(character.address, ethers.constants.MaxUint256);
            await character.connect(alice).buyNftWithGENESIS();
            await character.connect(approvedContract).setStatsWithPermission(tokenId, 1);

            const stats0 = await character.getStats(tokenId);
            const level0 = await character.getLevel(await character.tokenStats(tokenId));

            const input = await character.tokenStats(tokenId);
            const output = await character.increaseStats(input, [1, 1, 1, 1, 1, 1, 1]);
            console.log(input, output);

            await character.connect(approvedContract).levelUpWithPermission(tokenId, levels, [1, 1, 1, 1, 1, 1, 1]);
            const stats1 = await character.getStats(tokenId);
            const level1 = await character.getLevel(await character.tokenStats(tokenId));

            console.log(level1, level0);
            console.log(stats1);
            console.log(stats0);
            expect(level1.sub(level0)).to.be.equal(1);
            for (let i = 0; i < 7; i += 1) {
                expect(stats1[i].sub(stats0[i])).to.be.equal(statsPlus[i]);
            }
        });
    });
});
