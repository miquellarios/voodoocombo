class_name NetworkAddresses
extends RefCounted

const SKIP_ADAPTER_WORDS := ["vethernet", "virtualbox", "vmware", "wsl"]

static func candidates(interfaces: Array = IP.get_local_interfaces()) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for interface: Dictionary in interfaces:
		var name := str(interface.get("name", ""))
		var lower := name.to_lower()
		var skipped := false
		for word in SKIP_ADAPTER_WORDS:
			if lower.contains(word): skipped = true
		if skipped: continue
		for address_value in interface.get("addresses", []):
			var address := str(address_value)
			var rank := _rank(address, lower)
			if rank < 0: continue
			result.append({"name": name, "ip": address, "rank": rank})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.rank) < int(b.rank))
	return result

static func _rank(ip: String, adapter: String) -> int:
	var parts := ip.split(".")
	if parts.size() != 4: return -1
	for part in parts:
		if not part.is_valid_int() or int(part) < 0 or int(part) > 255: return -1
	var first := int(parts[0])
	var second := int(parts[1])
	if first == 26 or (first == 100 and second >= 64 and second <= 127): return 0
	if (first == 10 and second == 147) or (first == 172 and second >= 22 and second <= 30): return 1
	if adapter.contains("radmin") or adapter.contains("tailscale") or adapter.contains("zerotier"): return 1
	if first == 192 and second == 168: return 2
	if first == 10: return 3
	if first == 172 and second >= 16 and second <= 31: return 4
	return -1
