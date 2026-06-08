import Darwin
import Foundation

public enum NetworkAccessPolicy {
    public static func isTrusted(address rawAddress: String) -> Bool {
        let address = rawAddress.split(separator: "%", maxSplits: 1).first.map(String.init) ?? rawAddress

        var ipv4 = in_addr()
        if inet_pton(AF_INET, address, &ipv4) == 1 {
            let value = UInt32(bigEndian: ipv4.s_addr)
            let first = UInt8((value >> 24) & 0xff)
            let second = UInt8((value >> 16) & 0xff)
            return first == 10
                || first == 127
                || (first == 169 && second == 254)
                || (first == 172 && (16...31).contains(second))
                || (first == 192 && second == 168)
        }

        var ipv6 = in6_addr()
        if inet_pton(AF_INET6, address, &ipv6) == 1 {
            let bytes = withUnsafeBytes(of: &ipv6) { Array($0) }
            let loopback = bytes.dropLast().allSatisfy { $0 == 0 } && bytes.last == 1
            let linkLocal = bytes[0] == 0xfe && (bytes[1] & 0xc0) == 0x80
            let uniqueLocal = (bytes[0] & 0xfe) == 0xfc
            return loopback || linkLocal || uniqueLocal
        }

        return false
    }
}
