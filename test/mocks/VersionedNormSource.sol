// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.24;

import {ADRFTypes as T} from "adrf/ADRFTypes.sol";
import {IADRFDisputeRegistry} from "adrf/interfaces/IADRFDisputeRegistry.sol";
import {IADRFObligationSource} from "adrf/interfaces/IADRFObligationSource.sol";

/// Test-only business adapter: a terms amendment changes future deliveries, not past events.
/// The controller stands in for the business's amendment authorization. No funds or ERC-8448
/// implementation are involved; the real ADRF registry still performs admission and resolution.
contract VersionedNormSource is IADRFObligationSource {
    IADRFDisputeRegistry public immutable adrf;
    address public immutable controller;
    address public immutable client;
    address public immutable provider;
    uint8 public immutable kind;
    bytes32 public currentNorm;
    uint64 public declaredAt;
    mapping(bytes32 => T.EventInfo) private events;

    constructor(IADRFDisputeRegistry registry, address client_, address provider_, uint8 kind_) {
        adrf = registry;
        controller = msg.sender;
        client = client_;
        provider = provider_;
        kind = kind_;
    }

    modifier onlyController() {
        require(msg.sender == controller, "controller only");
        _;
    }

    function declareNorm(bytes32 norm) external onlyController {
        require(norm != bytes32(0), "empty norm");
        currentNorm = norm;
        declaredAt = uint64(block.timestamp);
    }

    function recordEvent(bytes32 eventRef) external onlyController {
        require(currentNorm != bytes32(0) && !events[eventRef].known, "invalid event");
        events[eventRef] = T.EventInfo({
            known: true,
            eventAt: uint64(block.timestamp),
            adoptionDeadline: uint64(block.timestamp + 30 days),
            obligationRef: keccak256(abi.encode(address(this), uint256(1), "delivery")),
            normRef: currentNorm,
            normDeclaredAt: declaredAt,
            obligationKind: kind
        });
    }

    function bind(T.BindingInput calldata input) external onlyController returns (bytes32) {
        return adrf.bind(input);
    }

    function objectOf(bytes32 eventRef) public view returns (T.ObjectRef memory) {
        return T.ObjectRef(block.chainid, address(this), 1, events[eventRef].normRef);
    }

    function propositionFor(bytes32 eventRef) public view returns (bytes32) {
        return keccak256(abi.encode(address(this), uint256(1), eventRef, "delivery conforms"));
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == 0x01ffc9a7 || id == type(IADRFObligationSource).interfaceId;
    }

    function known(T.ObjectRef calldata object, bytes32 eventRef) private view returns (bool) {
        return events[eventRef].known && object.chainId == block.chainid && object.target == address(this)
            && object.id == 1 && object.versionHash == events[eventRef].normRef;
    }

    function eventInfo(T.ObjectRef calldata object, bytes32 eventRef) external view returns (T.EventInfo memory info) {
        if (known(object, eventRef)) return events[eventRef];
    }

    function isParty(T.ObjectRef calldata object, bytes32 eventRef, address account) external view returns (bool) {
        return known(object, eventRef) && (account == client || account == provider);
    }

    function recognizesBreach(
        T.ObjectRef calldata object,
        bytes32 eventRef,
        uint8 obligationKind,
        bytes32 proposition,
        T.Value breachWhen
    ) external view returns (bool) {
        return known(object, eventRef) && obligationKind == kind && proposition == propositionFor(eventRef)
            && breachWhen == T.Value.FALSE;
    }
}
