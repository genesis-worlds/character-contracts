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

    before(async () => {
        [owner, alice, bob, feeReceiver] = await ethers.getSigners();
    });

    beforeEach(async () => {
        game = <MockToken>await deployContract("mockToken");
        genesis = <MockErc20>await deployContract("MockERC20", "Genesis token", "Gen", totalSupply);
        character = <Character>await deployContract("Character", game.address, genesis.address, feeReceiver.address);

        await game.transfer(alice.address, totalSupply.div(10));
        await game.transfer(bob.address, totalSupply.div(10));
        await genesis.transfer(alice.address, totalSupply.div(10));
        await genesis.transfer(bob.address, totalSupply.div(10));

        await game.updateLocalContract(character.address, true);
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
    });

    describe("buyNFT", () => {
        it("Get one nft using game", async () => {
            const price = await character.getPrice(1);

            await game.connect(alice).approve(character.address, ethers.constants.MaxUint256);
            const nftCount0 = await character.balanceOf(alice.address);
            const balance0 = await game.balanceOf(alice.address);
            await character.connect(alice).buyNftWithGAME();
            const nftCount1 = await character.balanceOf(alice.address);
            const balance1 = await game.balanceOf(alice.address);
            expect(nftCount1.sub(nftCount0)).to.be.equal(1);
            expect(balance0.sub(balance1)).to.be.equal(ethers.utils.parseUnits(price.toString(), 18));
        });

        it("Get one nft with GENESIS", async () => {
            const price = await character.getPrice(1);

            await genesis.connect(alice).approve(character.address, ethers.constants.MaxUint256);
            const nftCount0 = await character.balanceOf(alice.address);
            const balance0 = await genesis.balanceOf(alice.address);
            await character.connect(alice).buyNftWithGENESIS();
            const nftCount1 = await character.balanceOf(alice.address);
            const balance1 = await genesis.balanceOf(alice.address);
            expect(nftCount1.sub(nftCount0)).to.be.equal(1);
            expect(balance0.sub(balance1)).to.be.equal(ethers.utils.parseUnits(price.toString(), 18));
        });
    });

    describe("Level up", () => {
        it("levelUp", async () => {
            await genesis.connect(alice).approve(character.address, ethers.constants.MaxUint256);
            await character.connect(alice).buyNftWithGENESIS();

            const level0 = await character.tokenLevel(1);
            const balance0 = await genesis.balanceOf(alice.address);
            await character.connect(alice).levelUp(1);
            const level1 = await character.tokenLevel(1);
            const balance1 = await genesis.balanceOf(alice.address);
            expect(level1.sub(level0)).to.be.equal(1);
            expect(balance0.sub(balance1)).to.be.equal(level1.mul(ethers.utils.parseUnits("10", 18)));
        });
    });
});
