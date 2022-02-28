/* eslint-disable no-await-in-loop */
import { ethers } from "hardhat";
import { solidity } from "ethereum-waffle";
import chai from 'chai';
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { Character, MockErc20, MockToken } from "../typechain";
import { setNextBlockTimestamp, getLatestBlockTimestamp, mineBlock } from "../helper/utils";
import { deployContract } from "../helper/deployer";
import { IUniswapV2Router02 } from "../typechain/IUniswapV2Router02";

chai.use(solidity);
const { expect } = chai;

const WMATIC = "0x0d500b1d8e8ef31e21c99d1db9a6444d3adf1270"
const QuickSwapRouter = "0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff";

describe('Character Airdrop', () => {
    const totalSupply = ethers.utils.parseUnits("100000000", 18);

    let genesis: MockErc20;
    let game: MockToken;
    let character: Character;
    let owner: SignerWithAddress;
    let alice: SignerWithAddress;
    let bob: SignerWithAddress;
    let feeReceiver: SignerWithAddress;
    let router: IUniswapV2Router02;

    before(async () => {
        [owner, alice, bob, feeReceiver] = await ethers.getSigners();
    });

    beforeEach(async () => {
        game = <MockToken>await deployContract("mockToken");
        genesis = <MockErc20>await deployContract("MockERC20", "Genesis token", "Gen", totalSupply);
        character = <Character>await deployContract("Character", game.address, genesis.address, feeReceiver.address);

        await character.setUniswapRouter(QuickSwapRouter);

        await game.transfer(alice.address, totalSupply.div(10));
        await game.transfer(bob.address, totalSupply.div(10));
        await genesis.transfer(alice.address, totalSupply.div(10));
        await genesis.transfer(bob.address, totalSupply.div(10));

        await game.updateLocalContract(character.address, true);

        // Add liquidity for WMATIC-GAME pair
        router = <IUniswapV2Router02>await ethers.getContractAt("IUniswapV2Router02", QuickSwapRouter);
        const timestamp = await getLatestBlockTimestamp();
        await game.approve(router.address, ethers.constants.MaxUint256);
        await router.addLiquidityETH(game.address, ethers.utils.parseUnits("678579", 18), 0, 0, owner.address, timestamp + 100, { value: ethers.utils.parseUnits("29", 18) });
    });

    describe("buyNFTWithMatic", () => {
        it("Get one nft using genesis", async () => {
            const nftCount0 = await character.balanceOf(alice.address);

            const path = [WMATIC, game.address];
            const price = await character.getPrice(1);
            const out = await router.getAmountsIn(ethers.utils.parseUnits(price.toString(), 18), path);
            const priceInMatic = out[0];
            await character.connect(alice).buyNftwithMatic(path, { value: priceInMatic });

            const nftCount1 = await character.balanceOf(alice.address);
            expect(nftCount1.sub(nftCount0)).to.be.equal(1);
        });
    });
});
