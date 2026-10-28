// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.24;

import {ADRFTypes as T} from "adrf/ADRFTypes.sol";
import {IADRFDisputeRegistry} from "adrf/interfaces/IADRFDisputeRegistry.sol";
import {IADRFObligationSource} from "adrf/interfaces/IADRFObligationSource.sol";

/// Test double of an obligation source: every attestation is settable, so admission rules can be exercised one
/// by one (unknown event, norm mismatch, norm declared after the event, kind mismatch, parties).
contract MockSource is IADRFObligationSource {
    IADRFDisputeRegistry public immutable adrf;
    T.EventInfo public info;
    mapping(address => bool) public party;
    bytes32 public bindingId;

    constructor(IADRFDisputeRegistry adrf_) {
        adrf = adrf_;
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == 0x01ffc9a7 || interfaceId == type(IADRFObligationSource).interfaceId;
    }

    function setInfo(T.EventInfo calldata i) external { info = i; }
    function setParty(address who, bool yes) external { party[who] = yes; }

    function bind(T.BindingInput calldata input) external returns (bytes32) {
        bindingId = adrf.bind(input);
        return bindingId;
    }

    function revoke() external { adrf.revokeBinding(bindingId); }

    function eventInfo(T.ObjectRef calldata, bytes32) external view returns (T.EventInfo memory) { return info; }
    function isParty(T.ObjectRef calldata, bytes32, address account) external view returns (bool) { return party[account]; }

    function report(bytes32 caseId, bytes32 effectId, T.EnactmentStatus status, bytes32 ref) external {
        adrf.reportEnactment(caseId, effectId, status, ref);
    }
}

/// A contract that is not an obligation source (no ERC-165 support for the interface).
contract NotASource {
    function bind(IADRFDisputeRegistry adrf, T.BindingInput calldata input) external returns (bytes32) {
        return adrf.bind(input);
    }
}
