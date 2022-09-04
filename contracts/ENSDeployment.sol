pragma solidity >=0.8.16;
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

    bytes32 reverseNode = topLevelNode(REVERSE_REGISTRAR_LABEL);
    bytes32 reverseAddressNode = namehash(reverseNode, ADDR_LABEL);
    ReverseRegistrar reverseRegistrar = new ReverseRegistrar(ens, NameResolver(address(publicResolver)));
    ens.setSubnodeOwner(bytes32(0), REVERSE_REGISTRAR_LABEL, address(this));
    ens.setSubnodeOwner(reverseNode, ADDR_LABEL, address(this));
    ens.setResolver(reverseAddressNode, address(publicResolver));
    publicResolver.setAddr(reverseAddressNode, address(reverseRegistrar));
    ens.setSubnodeOwner(reverseNode, ADDR_LABEL, address(reverseRegistrar));

    // Give the caller control over the rest of the namespace.
    ens.setOwner(bytes32(0), msg.sender);
  }
}
