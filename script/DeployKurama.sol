// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Kurama} from "../src/Kurama.sol";

contract DeployKurama is Script {
    function run(address owner, address treasury) external returns (Kurama) {
        vm.startBroadcast();
        Kurama kurama = new Kurama(owner, treasury);
        vm.stopBroadcast();
        return kurama;
    }
}
