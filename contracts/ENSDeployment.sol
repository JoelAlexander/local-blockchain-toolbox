pragma solidity >=0.8.4;
import {INameWrapper, PublicResolver} from '@ensdomains/ens-contracts/contracts/resolvers/PublicResolver.sol';
import '@ensdomains/ens-contracts/contracts/registry/ENSRegistry.sol';
import '@ensdomains/ens-contracts/contracts/registry/FIFSRegistrar.sol';
import {NameResolver, ReverseRegistrar} from '@ensdomains/ens-contracts/contracts/registry/ReverseRegistrar.sol';

contract ENSDeployment {
  bytes32 public constant RESOLVER_LABEL = keccak256('resolver');
  bytes32 public constant REVERSE_REGISTRAR_LABEL = keccak256('reverse');
  bytes32 public constant ADDR_LABEL = keccak256('addr');

  ENSRegistry public ens;

  function namehash(bytes32 node, bytes32 label) public pure returns (bytes32) {
    return keccak256(abi.encodePacked(node, label));
  }

  function topLevelNode(bytes32 label) public pure returns (bytes32) {
    return namehash(bytes32(0), label);
  }

  constructor() public {
    ens = new ENSRegistry();

    bytes32 resolverNode = topLevelNode(RESOLVER_LABEL);
    PublicResolver publicResolver = new PublicResolver(ens, INameWrapper(address(0)));
    ens.setSubnodeOwner(bytes32(0), RESOLVER_LABEL, address(this));
    ens.setResolver(resolverNode, address(publicResolver));
    publicResolver.setAddr(resolverNode, address(publicResolver));

    // Calling addresses have full control over thier own reverse records.
    ReverseRegistrar reverseRegistrar = new ReverseRegistrar(ens, NameResolver(address(publicResolver)));
    ens.setSubnodeOwner(bytes32(0), REVERSE_REGISTRAR_LABEL, address(this));
    ens.setSubnodeOwner(topLevelNode(REVERSE_REGISTRAR_LABEL), ADDR_LABEL, address(reverseRegistrar));

    // Give the caller control over the rest of the namespace.
    ens.setOwner(bytes32(0), msg.sender);
  }
}
