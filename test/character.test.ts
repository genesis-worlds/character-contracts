/* eslint-disable no-await-in-loop */
import { ethers } from "hardhat";
import { solidity } from "ethereum-waffle";
import chai from 'chai';
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { Character, MockErc20 } from "../typechain";
import { setNextBlockTimestamp, getLatestBlockTimestamp, mineBlock } from "../helper/utils";
import { deployContract } from "../helper/deployer";

chai.use(solidity);
const { expect } = chai;

describe('Character Airdrop', () => {
    const totalSupply = ethers.utils.parseUnits("100000000", 18);

    let genesis: MockErc20;
    let airdrop: Character;
    let owner: SignerWithAddress;
    let alice: SignerWithAddress;
    let bob: SignerWithAddress;
    let feeReceiver: SignerWithAddress;;

    before(async () => {
        [owner, alice, bob, feeReceiver] = await ethers.getSigners();
    });

    beforeEach(async () => {
        genesis = <MockErc20>await deployContract("MockERC20", "Genesis token", "Gen", totalSupply);
        airdrop = <Character>await deployContract("Character", "TEST", "TEST", genesis.address, feeReceiver.address);

        await genesis.transfer(alice.address, totalSupply.div(10));
        await genesis.transfer(bob.address, totalSupply.div(10));
    });

    describe("distributeTokens", () => {
        it("Security", async () => {
            await expect(airdrop.connect(alice).distributeTokens([alice.address, bob.address])).to.be.reverted;
            await expect(airdrop.connect(bob).distributeTokens([alice.address, bob.address])).to.be.reverted;
        });

        it("Distribute tokens", async () => {
            await airdrop.distributeTokens([alice.address, bob.address]);
            expect(await airdrop.balanceOf(alice.address)).to.be.equal(1);
            expect(await airdrop.balanceOf(bob.address)).to.be.equal(1);
        });
    });

    describe("buyNFT", () => {
        it("Get one nft", async () => {
            await genesis.connect(alice).approve(airdrop.address, ethers.constants.MaxUint256);
            const nftCount0 = await airdrop.balanceOf(alice.address);
            const balance0 = await genesis.balanceOf(alice.address);
            await airdrop.connect(alice).buyNft();
            const nftCount1 = await airdrop.balanceOf(alice.address);
            const balance1 = await genesis.balanceOf(alice.address);
            expect(nftCount1.sub(nftCount0)).to.be.equal(1);
            expect(balance0.sub(balance1)).to.be.equal(ethers.utils.parseUnits("100", 18));
        });
    });

    describe("Level up", () => {
        it("levelUp", async () => {
            await genesis.connect(alice).approve(airdrop.address, ethers.constants.MaxUint256);
            await airdrop.connect(alice).buyNft();

            const level0 = await airdrop.getLevel(1);
            const balance0 = await genesis.balanceOf(alice.address);
            await airdrop.connect(alice).levelUp(1);
            const level1 = await airdrop.getLevel(1);
            const balance1 = await genesis.balanceOf(alice.address);
            expect(level1.sub(level0)).to.be.equal(1);
            expect(balance0.sub(balance1)).to.be.equal(level1.mul(ethers.utils.parseUnits("10", 18)));
        });
    });

    describe("Check airdrop", () => {
    });

    describe("Claim airdrop", () => {
    });
});
