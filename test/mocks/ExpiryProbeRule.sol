// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.24;

import {ADRFTypes as T} from "adrf/ADRFTypes.sol";
import {IADRFEvidenceRule} from "adrf/interfaces/IADRFEvidenceRule.sol";
import {IADRFDisputeRegistry} from "adrf/interfaces/IADRFDisputeRegistry.sol";

/// Test-only evidence rule whose behaviour at evaluation is set by the test: a regular answer (which also claims
/// the JUDGED support kind, so that the registry's mask can be seen), one of the ways a rule can fail to answer
/// (revert, short or out-of-range return data, an exhausted gas allowance), a valid answer padded with a large
/// amount of return data, a valid answer that takes HEAVY_WORK gas to compute and fails with less, or a valid
/// answer given after calling back into the registry once (applying the silence rule, or resolving the same
/// sub-question itself).
contract ExpiryProbeRule is IADRFEvidenceRule {
    enum Mode { Answer, Revert, Short, OutOfRange, Burn, Huge, Heavy, ReenterSilence, ReenterResolve }

    uint256 public constant HEAVY_WORK = 900_000;

    Mode public mode;
    T.Value public answer;
    uint256 public returnSize = 96;
    uint256 public evaluations;
    IADRFDisputeRegistry public registry;
    bool private _entered;

    function set(Mode m, T.Value a) external {
        mode = m;
        answer = a;
    }

    function setReturnSize(uint256 size) external {
        returnSize = size;
    }

    function setRegistry(IADRFDisputeRegistry r) external {
        registry = r;
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(IADRFEvidenceRule).interfaceId || interfaceId == 0x01ffc9a7;
    }

    function evaluate(bytes32 caseId, uint32 subQuestion, bytes32, bytes32, bytes calldata)
        external
        returns (T.Value, bytes32, uint8)
    {
        evaluations += 1;
        Mode m = mode;
        if ((m == Mode.ReenterSilence || m == Mode.ReenterResolve) && !_entered) {
            _entered = true;
            if (m == Mode.ReenterSilence) registry.applySilence(caseId);
            else registry.resolveEvidenced(caseId, subQuestion, "");
            _entered = false;
        }
        if (m == Mode.Revert) revert("probe: cannot answer");
        if (m == Mode.Short) {
            assembly {
                mstore(0, 1)
                return(0, 32)
            }
        }
        if (m == Mode.OutOfRange) {
            assembly {
                mstore(0, 7)
                mstore(32, 0)
                mstore(64, 4)
                return(0, 96)
            }
        }
        if (m == Mode.Burn) {
            uint256 x;
            while (gasleft() > 0) x += 1;
        }
        if (m == Mode.Heavy) {
            uint256 start = gasleft();
            while (start - gasleft() < HEAVY_WORK) {}
        }
        if (m == Mode.Huge) {
            uint256 size = returnSize;
            assembly {
                let p := mload(0x40)
                mstore(p, 2)
                mstore(add(p, 32), 0xabc)
                mstore(add(p, 64), 4)
                return(p, size)
            }
        }
        return (answer, keccak256("probe answer"), T.SUPPORT_EVIDENCED | T.SUPPORT_JUDGED);
    }
}
