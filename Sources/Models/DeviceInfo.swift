import Foundation

struct DeviceInfo: Identifiable, Codable, Equatable {
    let id: UUID
    let serialNumber: String
    let name: String
    let model: String
    let androidVersion: String
    var isConnected: Bool
    var connectionType: ConnectionType
    var totalStorage: Int64?
    var availableStorage: Int64?
    let lastConnected: Date
    
    init(serialNumber: String, name: String, model: String, androidVersion: String, isConnected: Bool = true, connectionType: ConnectionType = .usb) {
        self.id = UUID()
        self.serialNumber = serialNumber
        self.name = name
        self.model = model
        self.androidVersion = androidVersion
        self.isConnected = isConnected
        self.connectionType = connectionType
        self.lastConnected = Date()
    }
    
    var displayName: String {
        return name.isEmpty ? model : name
    }
    
    var statusText: String {
        return isConnected ? "已连接" : "未连接"
    }
    
    var formattedStorage: String {
        guard let total = totalStorage, let available = availableStorage else {
            return "存储信息不可用"
        }
        
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB]
        formatter.countStyle = .file
        
        let totalStr = formatter.string(fromByteCount: total)
        let availableStr = formatter.string(fromByteCount: available)
        let usedPercent = Int((Double(total - available) / Double(total)) * 100)
        
        return "\(availableStr) 可用 / \(totalStr) 总计 (已使用 \(usedPercent)%)"
    }
}

enum ConnectionType: String, Codable {
    case usb = "USB"
    case wifi = "Wi-Fi"
}
