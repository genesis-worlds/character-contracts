import { MerkleTree } from "merkletreejs";
import { ethers } from "hardhat";
import keccak256 from "keccak256";

export interface UserData {
  wallet: string;
}

export const getNode = (userInfo: UserData): string => ethers.utils.keccak256(
    ethers.utils.defaultAbiCoder.encode(
      ["address"],
      [userInfo.wallet]
    )
  );

export const generateTree = (userInfos: UserData[]): MerkleTree => {
  const leaves = userInfos.map((el) => getNode(el));

  return new MerkleTree(leaves, keccak256, { sort: true });
};
