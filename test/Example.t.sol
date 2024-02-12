// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import "./lib/YulDeployer.sol";

interface Example {}

contract ExampleTest is Test {
    YulDeployer yulDeployer = new YulDeployer();

    Example exampleContractParis;
    Example exampleContractShanghai;

    // function setUp() public {
    //     exampleContractParis = Example(yulDeployer.deployContractParis("Example"));
    //     exampleContractShanghai = Example(yulDeployer.deployContractShanghai("Example"));
    // }

    function testParis() public {
        exampleContractParis = Example(yulDeployer.deployContractParis("Example"));

        bytes memory callDataBytes = abi.encodeWithSignature("random()");

        (bool success, bytes memory data) = address(exampleContractParis).call{gas: 100000, value: 0}(callDataBytes);

        assertTrue(success);
        assertEq(data, callDataBytes);
    }

    function testShanghai() public {
        exampleContractShanghai = Example(yulDeployer.deployContractShanghai("Example"));

        bytes memory callDataBytes = abi.encodeWithSignature("random()");

        (bool success, bytes memory data) = address(exampleContractShanghai).call{gas: 100000, value: 0}(callDataBytes);

        assertTrue(success);
        //assertEq(data, callDataBytes);
    }
}
