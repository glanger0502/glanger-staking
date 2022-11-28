import { ethers, BigNumber } from 'ethers';
import fs from 'fs';

type Stage = {
    stageType: number,
    startTime: number,
    endTime: number,
    maxQuantity: number,
    price: BigNumber
}

let stage1: Stage = {
    stageType: 1,
    startTime: 1668591290, //2022-11-16 17:34:50
    endTime: 1670051868, //2022-12-03 15:17:48
    maxQuantity: 3,
    price: ethers.utils.parseUnits("0.1")
}

let stage2: Stage = {
    stageType: 2,
    startTime: 1668647561,
    endTime: 1670051868,
    maxQuantity: 3,
    price: ethers.utils.parseUnits("0.01")
}
const configs = {
    stage: {
        stage1: stage1,
        stage2: stage2
    },
    openBoxTime: 1669445844,
    newOpenBoxtime: 1671153161,
    totlaSupply: 7777,
    baseTokenURI: process.env.NEXT_PUBLIC_NFT_METADATA ? process.env.NEXT_PUBLIC_NFT_METADATA : '',
    openBoxBeforeURI: "hidden.json",
    mintTime: 1668850490, //2022-11-18 11:38:15
    buyPrice: ethers.utils.parseEther("0.1")
}

export {configs};