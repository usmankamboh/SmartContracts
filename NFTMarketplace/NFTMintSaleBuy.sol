//SPDX-License-Identifier: MIT
pragma solidity 0.8.14;
pragma abicoder v2;
abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return payable(msg.sender);
    }
    function _msgData() internal view virtual returns (bytes memory) {
        this;
        return msg.data;
    }
}
interface IBEP165 {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}
interface IBEP721 is IBEP165 {
    event Transfer(address indexed from,address indexed to,uint256 indexed tokenId);
    event Approval(address indexed owner,address indexed approved,uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner,address indexed operator,bool approved);
    function balanceOf(address owner) external view returns (uint256 balance);
    function ownerOf(uint256 tokenId) external view returns (address owner);
    function safeTransferFrom(address from,address to,uint256 tokenId) external;
    function transferFrom(address from,address to,uint256 tokenId) external;
    function approve(address to, uint256 tokenId) external;
    function getApproved(uint256 tokenId)external view returns (address operator);
    function setApprovalForAll(address operator, bool _approved) external;
    function isApprovedForAll(address owner, address operator)external view returns (bool);
    function safeTransferFrom(address from,address to,uint256 tokenId,bytes calldata data) external;
}
interface IBEP721Metadata is IBEP721 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function tokenURI(uint256 tokenId) external view returns (string memory);
}
interface IBEP721Enumerable is IBEP721 {
    function totalSupply() external view returns (uint256);
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256 tokenId);
    function tokenByIndex(uint256 index) external view returns (uint256);
}
interface IBEP721Receiver {
    function onBEP721Received(address operator,address from,uint256 tokenId,bytes calldata data) external returns (bytes4);
}
abstract contract BEP165 is IBEP165 {
    bytes4 private constant _INTERFACE_ID_BEP165 = 0x01ffc9a7;
    mapping(bytes4 => bool) private _supportedInterfaces;
    constructor() {
      _registerInterface(_INTERFACE_ID_BEP165);
    }
    function supportsInterface(bytes4 interfaceId)public view virtual override returns (bool){
        return _supportedInterfaces[interfaceId];
    }
    function _registerInterface(bytes4 interfaceId) internal virtual {
        require(interfaceId != 0xffffffff, "BEP165: invalid interface id");
        _supportedInterfaces[interfaceId] = true;
    }
}
library SafeMath {
    function tryAdd(uint256 a, uint256 b)internal pure returns (bool, uint256){
        uint256 c = a + b;
        if (c < a) return (false, 0);
        return (true, c);
    }
    function trySub(uint256 a, uint256 b)internal pure returns (bool, uint256){
        if (b > a) return (false, 0);
        return (true, a - b);
    }
    function tryMul(uint256 a, uint256 b)internal pure returns (bool, uint256){
        if (a == 0) return (true, 0);
        uint256 c = a * b;
        if (c / a != b) return (false, 0);
        return (true, c);
    }
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256){
        if (b == 0) return (false, 0);
        return (true, a / b);
    }
    function tryMod(uint256 a, uint256 b)internal pure returns (bool, uint256){
        if (b == 0) return (false, 0);
        return (true, a % b);
    }
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        return a - b;
    }
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) return 0;
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: division by zero");
        return a / b;
    }
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: modulo by zero");
        return a % b;
    }
    function sub(uint256 a,uint256 b,string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        return a - b;
    }
    function div(uint256 a,uint256 b,string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        return a / b;
    }
    function mod(uint256 a,uint256 b,string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        return a % b;
    }
}
library Address {
    function isContract(address account) internal view returns (bool) {
        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount,"Address: insufficient balance");
        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = recipient.call{value: amount}("");
        require(success,"Address: unable to send value, recipient may have reverted");
    }
    function functionCall(address target, bytes memory data)internal returns (bytes memory){
        return functionCall(target, data, "Address: low-level call failed");
    }
    function functionCall(address target,bytes memory data,string memory errorMessage) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }
    function functionCallWithValue(address target,bytes memory data,uint256 value) internal returns (bytes memory) {
        return functionCallWithValue(target,data,value,"Address: low-level call with value failed");
    }
    function functionCallWithValue(address target,bytes memory data,uint256 value,string memory errorMessage) internal returns (bytes memory) {
        require(address(this).balance >= value,"Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");
        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }
    function functionStaticCall(address target, bytes memory data)internal view returns (bytes memory){
        return functionStaticCall(target,data,"Address: low-level static call failed");
    }
    function functionStaticCall(address target,bytes memory data,string memory errorMessage) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");
        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.staticcall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }
    function functionDelegateCall(address target, bytes memory data)internal returns (bytes memory){
        return functionDelegateCall(target,data,"Address: low-level delegate call failed");
    }
    function functionDelegateCall(address target,bytes memory data,string memory errorMessage) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");
        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }
    function _verifyCallResult(bool success,bytes memory returndata,string memory errorMessage) private pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly
                // solhint-disable-next-line no-inline-assembly
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}
library EnumerableSet {
    struct Set {
        // Storage of set values
        bytes32[] _values;
        // Position of the value in the `values` array, plus 1 because index 0
        // means a value is not in the set.
        mapping(bytes32 => uint256) _indexes;
    }
    function _add(Set storage set, bytes32 value) private returns (bool) {
        if (!_contains(set, value)) {
            set._values.push(value);
            // The value is stored at length-1, but we add 1 to all indexes
            // and use 0 as a sentinel value
            set._indexes[value] = set._values.length;
            return true;
        } else {
            return false;
        }
    }
    function _remove(Set storage set, bytes32 value) private returns (bool) {
        // We read and store the value's index to prevent multiple reads from the same storage slot
        uint256 valueIndex = set._indexes[value];
        if (valueIndex != 0) {
            // Equivalent to contains(set, value)
            uint256 toDeleteIndex = valueIndex - 1;
            uint256 lastIndex = set._values.length - 1;
            // When the value to delete is the last one, the swap operation is unnecessary. However, since this occurs
            // so rarely, we still do the swap anyway to avoid the gas cost of adding an 'if' statement.
            bytes32 lastvalue = set._values[lastIndex];
            // Move the last value to the index where the value to delete is
            set._values[toDeleteIndex] = lastvalue;
            // Update the index for the moved value
            set._indexes[lastvalue] = toDeleteIndex + 1; // All indexes are 1-based
            // Delete the slot where the moved value was stored
            set._values.pop();
            // Delete the index for the deleted slot
            delete set._indexes[value];
            return true;
        } else {
            return false;
        }
    }
    function _contains(Set storage set, bytes32 value)private view returns (bool){
        return set._indexes[value] != 0;
    }
    function _length(Set storage set) private view returns (uint256) {
        return set._values.length;
    }
    function _at(Set storage set, uint256 index) private view returns (bytes32){
        require(set._values.length > index,"EnumerableSet: index out of bounds");
        return set._values[index];
    }
    // Bytes32Set
    struct Bytes32Set {
        Set _inner;
    }
    function add(Bytes32Set storage set, bytes32 value)internal returns (bool){
        return _add(set._inner, value);
    }
    function remove(Bytes32Set storage set, bytes32 value) internal returns (bool){
        return _remove(set._inner, value);
    }
    function contains(Bytes32Set storage set, bytes32 value)internal view returns (bool){
        return _contains(set._inner, value);
    }
    function length(Bytes32Set storage set) internal view returns (uint256) {
        return _length(set._inner);
    }
    function at(Bytes32Set storage set, uint256 index)internal view returns (bytes32){
        return _at(set._inner, index);
    }
    // AddressSet
    struct AddressSet {
        Set _inner;
    }
    function add(AddressSet storage set, address value)internal returns (bool){
        return _add(set._inner, bytes32(uint256(uint160(value))));
    }
    function remove(AddressSet storage set, address value)internal returns (bool){
        return _remove(set._inner, bytes32(uint256(uint160(value))));
    }
    function contains(AddressSet storage set, address value)internal view returns (bool){
        return _contains(set._inner, bytes32(uint256(uint160(value))));
    }
    function length(AddressSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }
    function at(AddressSet storage set, uint256 index) internal view returns (address){
        return address(uint160(uint256(_at(set._inner, index))));
    }
    // UintSet
    struct UintSet {
        Set _inner;
    }
    function add(UintSet storage set, uint256 value) internal returns (bool) {
        return _add(set._inner, bytes32(value));
    }
    function remove(UintSet storage set, uint256 value) internal returns (bool){
        return _remove(set._inner, bytes32(value));
    }
    function contains(UintSet storage set, uint256 value)internal view returns (bool){
        return _contains(set._inner, bytes32(value));
    }
    function length(UintSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }
    function at(UintSet storage set, uint256 index)internal view returns (uint256){
        return uint256(_at(set._inner, index));
    }
}
library EnumerableMap {
    struct MapEntry {
        bytes32 _key;
        bytes32 _value;
    }
    struct Map {
        // Storage of map keys and values
        MapEntry[] _entries;
        mapping(bytes32 => uint256) _indexes;
    }
    function _set(Map storage map,bytes32 key,bytes32 value) private returns (bool) {
        // We read and store the key's index to prevent multiple reads from the same storage slot
        uint256 keyIndex = map._indexes[key];
        if (keyIndex == 0) {
            // Equivalent to !contains(map, key)
            map._entries.push(MapEntry({_key: key, _value: value}));
            // The entry is stored at length-1, but we add 1 to all indexes
            // and use 0 as a sentinel value
            map._indexes[key] = map._entries.length;
            return true;
        } else {
            map._entries[keyIndex - 1]._value = value;
            return false;
        }
    }
    function _remove(Map storage map, bytes32 key) private returns (bool) {
        // We read and store the key's index to prevent multiple reads from the same storage slot
        uint256 keyIndex = map._indexes[key];
        if (keyIndex != 0) {
            uint256 toDeleteIndex = keyIndex - 1;
            uint256 lastIndex = map._entries.length - 1;
            MapEntry storage lastEntry = map._entries[lastIndex];
            // Move the last entry to the index where the entry to delete is
            map._entries[toDeleteIndex] = lastEntry;
            // Update the index for the moved entry
            map._indexes[lastEntry._key] = toDeleteIndex + 1; // All indexes are 1-based
            // Delete the slot where the moved entry was stored
            map._entries.pop();
            // Delete the index for the deleted slot
            delete map._indexes[key];
            return true;
        } else {
            return false;
        }
    }
    function _contains(Map storage map, bytes32 key)private view returns (bool){
        return map._indexes[key] != 0;
    }
    function _length(Map storage map) private view returns (uint256) {
        return map._entries.length;
    }
    function _at(Map storage map, uint256 index)private view returns (bytes32, bytes32){
        require(map._entries.length > index,"EnumerableMap: index out of bounds");
        MapEntry storage entry = map._entries[index];
        return (entry._key, entry._value);
    }
    function _tryGet(Map storage map, bytes32 key)private view returns (bool, bytes32){
        uint256 keyIndex = map._indexes[key];
        if (keyIndex == 0) return (false, 0); // Equivalent to contains(map, key)
        return (true, map._entries[keyIndex - 1]._value); // All indexes are 1-based
    }
    function _get(Map storage map, bytes32 key) private view returns (bytes32) {
        uint256 keyIndex = map._indexes[key];
        require(keyIndex != 0, "EnumerableMap: nonexistent key"); // Equivalent to contains(map, key)
        return map._entries[keyIndex - 1]._value; // All indexes are 1-based
    }
    function _get(Map storage map,bytes32 key,string memory errorMessage) private view returns (bytes32) {
        uint256 keyIndex = map._indexes[key];
        require(keyIndex != 0, errorMessage); // Equivalent to contains(map, key)
        return map._entries[keyIndex - 1]._value; // All indexes are 1-based
    }
    // UintToAddressMap
    struct UintToAddressMap {
        Map _inner;
    }
    function set(UintToAddressMap storage map,uint256 key,address value) internal returns (bool) {
        return _set(map._inner, bytes32(key), bytes32(uint256(uint160(value))));
    }
    function remove(UintToAddressMap storage map, uint256 key)internal returns (bool){
        return _remove(map._inner, bytes32(key));
    }
    function contains(UintToAddressMap storage map, uint256 key) internal view returns (bool){
        return _contains(map._inner, bytes32(key));
    }
    function length(UintToAddressMap storage map)internal view returns (uint256){
        return _length(map._inner);
    }
    function at(UintToAddressMap storage map, uint256 index)internal view returns (uint256, address){
        (bytes32 key, bytes32 value) = _at(map._inner, index);
        return (uint256(key), address(uint160(uint256(value))));
    }
    function tryGet(UintToAddressMap storage map, uint256 key)internal view returns (bool, address){
        (bool success, bytes32 value) = _tryGet(map._inner, bytes32(key));
        return (success, address(uint160(uint256(value))));
    }
    function get(UintToAddressMap storage map, uint256 key)internal view returns (address){
        return address(uint160(uint256(_get(map._inner, bytes32(key)))));
    }
    function get(UintToAddressMap storage map,uint256 key,string memory errorMessage) internal view returns (address) {
        return address(uint160(uint256(_get(map._inner, bytes32(key), errorMessage))));
    }
}
library Strings {
    function toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        uint256 index = digits - 1;
        temp = value;
        while (temp != 0) {
            buffer[index--] = bytes1(uint8(48 + (temp % 10)));
            temp /= 10;
        }
        return string(buffer);
    }
}
contract BEP721 is Context,BEP165,IBEP721,IBEP721Metadata,IBEP721Enumerable{
    using SafeMath for uint256;
    using Address for address;
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableMap for EnumerableMap.UintToAddressMap;
    using Strings for uint256;
    // Equals to `bytes4(keccak256("onBEP721Received(address,address,uint256,bytes)"))`
    // which can be also obtained as `IBEP721Receiver(0).onBEP721Received.selector`
    bytes4 private constant _BEP721_RECEIVED = 0x150b7a02;
    // Mapping from holder address to their (enumerable) set of owned tokens
    mapping(address => EnumerableSet.UintSet) private _holderTokens;
    // Enumerable mapping from token ids to their owners
    EnumerableMap.UintToAddressMap private _tokenOwners;
    // Mapping from token ID to approved address
    mapping(uint256 => address) private _tokenApprovals;
    // Mapping from owner to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;
    // Token name
    string private _name;
    // Token symbol
    string private _symbol;
    // Optional mapping for token URIs
    mapping(uint256 => string) private _tokenURIs;
    // Base URI
    string private _baseURI;
    bytes4 private constant _INTERFACE_ID_BEP721 = 0x80ac58cd;
    bytes4 private constant _INTERFACE_ID_BEP721_METADATA = 0x5b5e139f;
    bytes4 private constant _INTERFACE_ID_BEP721_ENUMERABLE = 0x780e9d63;
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
        // register the supported interfaces to conform to BEP721 via BEP165
        _registerInterface(_INTERFACE_ID_BEP721);
        _registerInterface(_INTERFACE_ID_BEP721_METADATA);
        _registerInterface(_INTERFACE_ID_BEP721_ENUMERABLE);
    }
    function balanceOf(address owner)public view virtual override returns (uint256){
        require(owner != address(0),"BEP721: balance query for the zero address");
        return _holderTokens[owner].length();
    }
    function ownerOf(uint256 tokenId)public view virtual override returns (address){
        return _tokenOwners.get(tokenId,"BEP721: owner query for nonexistent token");
    }
    function name() public view virtual override returns (string memory) {
        return _name;
    }
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }
    function tokenURI(uint256 tokenId)public view virtual override returns (string memory){
        require(_exists(tokenId),"BEP721Metadata: URI query for nonexistent token");
        string memory _tokenURI = _tokenURIs[tokenId];
        string memory base = baseURI();
        // If there is no base URI, return the token URI.
        if (bytes(base).length == 0) {
            return _tokenURI;
        }
        // If both are set, concatenate the baseURI and tokenURI (via abi.encodePacked).
        if (bytes(_tokenURI).length > 0) {
            return string(abi.encodePacked(base, _tokenURI));
        }
        // If there is a baseURI but no tokenURI, concatenate the tokenID to the baseURI.
        return string(abi.encodePacked(base, tokenId.toString()));
    }
    function baseURI() public view virtual returns (string memory) {
        return _baseURI;
    }
    function tokenOfOwnerByIndex(address owner, uint256 index)public view virtual override returns (uint256){
        return _holderTokens[owner].at(index);
    }
    function totalSupply() public view virtual override returns (uint256) {
        // _tokenOwners are indexed by tokenIds, so .length() returns the number of tokenIds
        return _tokenOwners.length();
    }
    function tokenByIndex(uint256 index) public view virtual override returns (uint256){
        (uint256 tokenId, ) = _tokenOwners.at(index);
        return tokenId;
    }
    function approve(address to, uint256 tokenId) public virtual override {
        address owner = BEP721.ownerOf(tokenId);
        require(to != owner, "BEP721: approval to current owner");
        require(_msgSender() == owner || BEP721.isApprovedForAll(owner, _msgSender()),"BEP721: approve caller is not owner nor approved for all");
        _approve(to, tokenId);
    }
    function getApproved(uint256 tokenId)public view virtual override returns (address){
        require(_exists(tokenId),"BEP721: approved query for nonexistent token");
        return _tokenApprovals[tokenId];
    }
    function setApprovalForAll(address operator, bool approved)public virtual override{
        require(operator != _msgSender(), "BEP721: approve to caller");
        _operatorApprovals[_msgSender()][operator] = approved;
        emit ApprovalForAll(_msgSender(), operator, approved);
    }
    function isApprovedForAll(address owner, address operator)public view virtual override returns (bool){
        return _operatorApprovals[owner][operator];
    }
    function transferFrom(address from,address to,uint256 tokenId) public virtual override {
        //solhint-disable-next-line max-line-length
        require(_isApprovedOrOwner(_msgSender(), tokenId),"BEP721: transfer caller is not owner nor approved");
        _transfer(from, to, tokenId);
    }
    function safeTransferFrom(address from,address to,uint256 tokenId) public virtual override {
        safeTransferFrom(from, to, tokenId, "");
    }
    function safeTransferFrom(address from,address to,uint256 tokenId,bytes memory _data) public virtual override {
        require(_isApprovedOrOwner(_msgSender(), tokenId),"BEP721: transfer caller is not owner nor approved");
        _safeTransfer(from, to, tokenId, _data);
    }
    function _safeTransfer(address from,address to,uint256 tokenId,bytes memory _data) internal virtual {
        _transfer(from, to, tokenId);
        require(_checkOnBEP721Received(from, to, tokenId, _data),"BEP721: transfer to non BEP721Receiver implementer");
    }
    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return _tokenOwners.contains(tokenId);
    }
    function _isApprovedOrOwner(address spender, uint256 tokenId)internal view virtual returns (bool){
        require(_exists(tokenId),"BEP721: operator query for nonexistent token");
        address owner = BEP721.ownerOf(tokenId);
        return (spender == owner || getApproved(tokenId) == spender || BEP721.isApprovedForAll(owner, spender));
    }
    function _safeMint(address to, uint256 tokenId) internal virtual {
        _safeMint(to, tokenId, "");
    }
    function _safeMint(address to,uint256 tokenId,bytes memory _data) internal virtual {
        _mint(to, tokenId);
        require(_checkOnBEP721Received(address(0), to, tokenId, _data),"BEP721: transfer to non BEP721Receiver implementer");
    }
    function _mint(address to, uint256 tokenId) internal virtual {
        require(to != address(0), "BEP721: mint to the zero address");
        require(!_exists(tokenId), "BEP721: token already minted");
        _beforeTokenTransfer(address(0), to, tokenId);
        _holderTokens[to].add(tokenId);
        _tokenOwners.set(tokenId, to);
        emit Transfer(address(0), to, tokenId);
    }
    function _burn(uint256 tokenId) internal virtual {
        address owner = BEP721.ownerOf(tokenId); // internal owner
        _beforeTokenTransfer(owner, address(0), tokenId);
        // Clear approvals
        _approve(address(0), tokenId);
        // Clear metadata (if any)
        if (bytes(_tokenURIs[tokenId]).length != 0) {
            delete _tokenURIs[tokenId];
        }
        _holderTokens[owner].remove(tokenId);
        _tokenOwners.remove(tokenId);
        emit Transfer(owner, address(0), tokenId);
    }
    function _transfer(address from,address to,uint256 tokenId) internal virtual {
        require(BEP721.ownerOf(tokenId) == from,"BEP721: transfer of token that is not own"); // internal owner
        require(to != address(0), "BEP721: transfer to the zero address");
        _beforeTokenTransfer(from, to, tokenId);
        // Clear approvals from the previous owner
        _approve(address(0), tokenId);
        _holderTokens[from].remove(tokenId);
        _holderTokens[to].add(tokenId);
        _tokenOwners.set(tokenId, to);
        emit Transfer(from, to, tokenId);
    }
    function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal virtual{
        require(_exists(tokenId),"BEP721Metadata: URI set of nonexistent token");
        _tokenURIs[tokenId] = _tokenURI;
    }
    function _setBaseURI(string memory baseURI_) internal virtual {
        _baseURI = baseURI_;
    }
    function _checkOnBEP721Received(address from,address to,uint256 tokenId,bytes memory _data) private returns (bool) {
        if (!to.isContract()) {
            return true;
        }
        bytes memory returndata = to.functionCall(
            abi.encodeWithSelector(IBEP721Receiver(to).onBEP721Received.selector,_msgSender(),from,
                tokenId,_data),"BEP721: transfer to non BEP721Receiver implementer");
        bytes4 retval = abi.decode(returndata, (bytes4));
        return (retval == _BEP721_RECEIVED);
    }
    function _approve(address to, uint256 tokenId) internal virtual {
        _tokenApprovals[tokenId] = to;
        emit Approval(BEP721.ownerOf(tokenId), to, tokenId); // internal owner
    }
    function _beforeTokenTransfer(address from,address to,uint256 tokenId) internal virtual {}
}
abstract contract BEP721URIStorage is BEP721 {
    using Strings for uint256;
    // Optional mapping for token URIs
    mapping(uint256 => string) private _tokenURIs;
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory){
         require(_exists(tokenId),"BEP721URIStorage: URI query for nonexistent token");
        string memory _tokenURI = _tokenURIs[tokenId];
        string memory base = baseURI();
        // If there is no base URI, return the token URI.
        if (bytes(base).length == 0) {
            return _tokenURI;
        }
        // If both are set, concatenate the baseURI and tokenURI (via abi.encodePacked).
        if (bytes(_tokenURI).length > 0) {
            return string(abi.encodePacked(base, _tokenURI));
        }
        return super.tokenURI(tokenId);
    }
    function _burn(uint256 tokenId) internal virtual override {
        super._burn(tokenId);
        if (bytes(_tokenURIs[tokenId]).length != 0) {
            delete _tokenURIs[tokenId];
        }
    }
}
library Counters {
    struct Counter {
        uint256 _value; // default: 0
    }
    function current(Counter storage counter) internal view returns (uint256) {
        return counter._value;
    }
    function increment(Counter storage counter) internal {
        unchecked {
            counter._value += 1;
        }
    }
    function decrement(Counter storage counter) internal {
        uint256 value = counter._value;
        require(value > 0, "Counter: decrement overflow");
        unchecked {
            counter._value = value - 1;
        }
    }
    function reset(Counter storage counter) internal {
        counter._value = 0;
    }
}
abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;
    constructor() {
        _status = _NOT_ENTERED;
    }
    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}
// smart contract inherits BEP721 interface
contract SSSNFTMarket is BEP721 {
    // this contract's token collection name
    string public collectionName;
    // this contract's token symbol
    string public collectionNameSymbol;
    // total number of nfts minteda
    uint256 public nftCounter;
    address payable owner = payable(0xC5C65074064e5283C9D40403208Af004c8960b95);
    // define nft struct
    struct NFT {
        uint256 tokenId;
        string tokenURI;
        address payable mintedBy;
        address payable currentOwner;
        address payable previousOwner;
        uint256 price;
        uint256 numberOfTransfers;
        bool forSale;
    }
    uint256 listingPrice = 0.2 ether;
    // map nft's token id to nft
    mapping(uint256 => NFT) public allNFT;
    // check if token name exists
    mapping(string => bool) public tokenNameExists;
    // check if token URI exists
    mapping(string => bool) public tokenURIExists;
    // initialize contract while deployment with contract's collection name and token
    constructor() BEP721("SSSNFT", "SSSN") {
        collectionName = name();
        collectionNameSymbol = symbol();
    }
    // mint a new nft
    function mintNFT(string memory _tokenURI,uint256 _price) external payable {
        // check if thic fucntion caller is not an zero address account
        require(msg.sender != address(0));
        // increment counter
        nftCounter++;
        // check if a token exists with the above token id => incremented counter
        require(!_exists(nftCounter));
        // check if the token URI already exists or not
        require(!tokenURIExists[_tokenURI]);
        // check if the token name already exists or not
        require(_price > 0, "Price must be at least 1 wei");
        require(
            msg.value == listingPrice,
            "Price must be equal to listing+minting"
        );
        // mint the token
        _mint(msg.sender, nftCounter);
        // set token URI (bind token id with the passed in token URI)
        _setTokenURI(nftCounter, _tokenURI);
        // make passed token URI as exists
        tokenURIExists[_tokenURI] = true;
        // make token name passed as exists
        // creat a new nft (struct) and pass in new values
        NFT memory newNFT = NFT(
            nftCounter,
            _tokenURI,
            payable(msg.sender),
            payable(msg.sender),
            payable(address(0)),
            _price,
            0,
            true
        );
        payable(owner).transfer(listingPrice);
        // add the token id and it's nft to all nfts mapping
        allNFT[nftCounter] = newNFT;
    }

    // get owner of the token
    function getTokenOwner(uint256 _tokenId) public view returns (address) {
        address _tokenOwner = ownerOf(_tokenId);
        return _tokenOwner;
    }

    // get metadata of the token
    function getTokenMetaData(uint256 _tokenId)
        public
        view
        returns (string memory)
    {
        string memory tokenMetaData = tokenURI(_tokenId);
        return tokenMetaData;
    }

    // get total number of tokens minted so far
    function getNumberOfTokensMinted() public view returns (uint256) {
        uint256 totalNumberOfTokensMinted = totalSupply();
        return totalNumberOfTokensMinted;
    }

    // get total number of tokens owned by an address
    function getTotalNumberOfTokensOwnedByAnAddress(address _owner)
        public
        view
        returns (uint256)
    {
        uint256 totalNumberOfTokensOwned = balanceOf(_owner);
        return totalNumberOfTokensOwned;
    }

    // check if the token already exists
    function getTokenExists(uint256 _tokenId) public view returns (bool) {
        bool tokenExists = _exists(_tokenId);
        return tokenExists;
    }

    // by a token by passing in the token's id
    function buyNFT(uint256 _tokenId) public payable {
        // check if the function caller is not an zero account address
        require(msg.sender != address(0));
        // check if the token id of the token being bought exists or not
        require(_exists(_tokenId));
        // get the token's owner
        address tokenOwner = ownerOf(_tokenId);
        // token's owner should not be an zero address account
        require(tokenOwner != address(0));
        // the one who wants to buy the token should not be the token's owner
        require(tokenOwner != msg.sender);
        // get that token from all nfts mapping and create a memory of it defined as (struct => NFT)
        NFT memory nft = allNFT[_tokenId];
        // price sent in to buy should be equal to or more than the token's price
        require(msg.value >= nft.price);
        // token should be for sale
        require(nft.forSale);
        // transfer the token from owner to the caller of the function (buyer)
        _transfer(tokenOwner, msg.sender, _tokenId);
        // get owner of the token
        address payable sendTo = nft.currentOwner;
        // send token's worth of BNB to the owner
        sendTo.transfer(msg.value);
        // update the token's previous owner
        nft.previousOwner = nft.currentOwner;
        // update the token's current owner
        nft.currentOwner = payable(msg.sender);
        // update the how many times this token was transfered
        nft.numberOfTransfers += 1;
        // set and update that token in the mapping
        allNFT[_tokenId] = nft;
    }
    function changeTokenPrice(uint256 _tokenId, uint256 _newPrice) public {
        // require caller of the function is not an empty address
        require(msg.sender != address(0));
        // require that token should exist
        require(_exists(_tokenId));
        // get the token's owner
        address tokenOwner = ownerOf(_tokenId);
        // check that token's owner should be equal to the caller of the function
        require(tokenOwner == msg.sender);
        // get that token from all nfts mapping and create a memory of it defined as (struct => NFT)
        NFT memory nft = allNFT[_tokenId];
        // update token's price with new price
        nft.price = _newPrice;
        // set and update that token in the mapping
        allNFT[_tokenId] = nft;
    }

    // switch between set for sale and set not for sale
    function toggleForSale(uint256 _tokenId)public {
        // require caller of the function is not an empty address
        require(msg.sender != address(0));
        // require that token should exist
        require(_exists(_tokenId));
        // get the token's owner
        address tokenOwner = ownerOf(_tokenId);
        // check that token's owner should be equal to the caller of the function
        require(tokenOwner == msg.sender);
        // get that token from all nfts mapping and create a memory of it defined as (struct => NFT)
        NFT memory nft = allNFT[_tokenId];
        // if token's forSale is false make it true and vice versa
        if (nft.forSale) {
            nft.forSale = false;
        } else {
            nft.forSale = true;
        }
        // set and update that token in the mapping
        allNFT[_tokenId] = nft;
    }

    //  function to get listingprice
    function getListingPrice() public view returns (uint256) {
        return listingPrice;
    }

    function setListingPrice(uint256 _price) public returns (uint256) {
        if (msg.sender == address(this)) {
            listingPrice = _price;
        }
        return listingPrice;
    }
}