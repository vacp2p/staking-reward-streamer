// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IStakeManager } from "./IStakeManager.sol";
import { ITransparentProxy } from "./ITransparentProxy.sol";

// solhint-disable-next-line
interface IStakeManagerProxy is IStakeManager, ITransparentProxy { }
