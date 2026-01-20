import SwiftUI

/// Wi-Fi 连接视图 - 用于连接通过 Wi-Fi 提供服务的安卓设备
struct WiFiConnectionView: View {
    @ObservedObject private var wifiManager = WiFiManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var host: String = ""
    @State private var port: String = "8080"
    @State private var selectedProtocol: WiFiProtocol = .http
    @State private var isConnecting: Bool = false
    @State private var errorMessage: String?
    @State private var showError: Bool = false
    @State private var ftpUsername: String = ""
    @State private var ftpPassword: String = ""
    
    var body: some View {
        VStack(spacing: 20) {
            // 标题
            HStack {
                Image(systemName: "wifi")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text("Wi-Fi 连接")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            Divider()
            
            // 连接表单
            Form {
                Section("连接信息") {
                    TextField("IP 地址", text: $host)
                        .textFieldStyle(.roundedBorder)
                        .help("安卓设备的 IP 地址，例如: 192.168.1.100")
                    
                    TextField("端口", text: $port)
                        .textFieldStyle(.roundedBorder)
                        .help("服务端口，默认 8080")
                    
                    Picker("协议", selection: $selectedProtocol) {
                        ForEach(WiFiProtocol.allCases, id: \.self) { proto in
                            Text(proto.rawValue).tag(proto)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                if selectedProtocol == .ftp {
                    Section("FTP 凭据 (可选)") {
                        TextField("用户名", text: $ftpUsername)
                            .textFieldStyle(.roundedBorder)
                            .help("如果 FTP 服务器需要，请输入用户名。")
                        
                        SecureField("密码", text: $ftpPassword)
                            .textFieldStyle(.roundedBorder)
                            .help("如果 FTP 服务器需要，请输入密码。")
                    }
                }
                
                Section("说明") {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("在安卓设备上启动文件服务器应用", systemImage: "1.circle")
                        Label("确保 Mac 和安卓设备在同一网络", systemImage: "2.circle")
                        Label("输入安卓设备显示的 IP 地址和端口", systemImage: "3.circle")
                        Label("点击「连接」按钮", systemImage: "4.circle")
                    }
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                }
            }
            .formStyle(.grouped)
            
            // 已连接设备列表
            if !wifiManager.connectedDevices.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("已连接设备")
                            .font(.headline)
                        
                        ForEach(wifiManager.connectedDevices) { device in
                            WiFiDeviceRow(device: device) {
                                wifiManager.disconnect(device: device)
                            }
                        }
                    }
                }
            }
            
            Spacer()
            
            // 操作按钮
            HStack {
                Button("取消") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
                
                Spacer()
                
                if isConnecting {
                    ProgressView()
                        .scaleEffect(0.8)
                }
                
                Button("连接") {
                    connect()
                }
                .buttonStyle(.borderedProminent)
                .disabled(host.isEmpty || isConnecting)
                .keyboardShortcut(.return)
            }
        }
        .padding()
        .frame(width: 450, height: 500)
        .alert("连接失败", isPresented: $showError) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "未知错误")
        }
    }
    
    private func connect() {
        guard let portNumber = Int(port), portNumber > 0, portNumber < 65536 else {
            errorMessage = "端口号无效"
            showError = true
            return
        }
        
        isConnecting = true
        
        Task {
            do {
                // 根据协议传递 FTP 的凭据（HTTP/HTTPS 忽略）
                let device = try await wifiManager.connect(
                    host: host,
                    port: portNumber,
                    wifiProtocol: selectedProtocol,
                    username: selectedProtocol == .ftp ? (ftpUsername.isEmpty ? nil : ftpUsername) : nil,
                    password: selectedProtocol == .ftp ? (ftpPassword.isEmpty ? nil : ftpPassword) : nil
                )
                
                await MainActor.run {
                    isConnecting = false
                    LogManager.shared.log("Wi-Fi 设备连接成功: \(device.displayName)", level: .info, category: "WiFi")
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isConnecting = false
                    // 更友好提示针对 FTP 的常见问题
                    if let wifiErr = error as? WiFiError {
                        errorMessage = wifiErr.errorDescription
                    } else {
                        errorMessage = error.localizedDescription
                    }
                    
                    // 如果是 FTP 相关错误，补充说明
                    if selectedProtocol == .ftp {
                        errorMessage = (errorMessage ?? "") + "\n\n提示：请检查 FTP 服务是否启用、IP/端口是否正确，若需要用户名/密码请填写；某些 FTP 服务器需要被动模式或限制了匿名访问。"
                    }
                    
                    showError = true
                }
            }
        }
    }
}

struct WiFiDeviceRow: View {
    let device: WiFiDeviceInfo
    let onDisconnect: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "wifi")
                .foregroundColor(.green)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(device.displayName)
                    .font(.system(size: 13))
                
                Text("\(device.host):\(device.port)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("断开") {
                onDisconnect()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

// MARK: - 推荐的安卓应用

struct RecommendedAppsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("推荐安卓应用")
                .font(.headline)
            
            Text("以下应用可在安卓设备上提供文件服务器功能：")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                AppRecommendation(
                    name: "Solid Explorer",
                    description: "内置 FTP 服务器功能",
                    url: "https://play.google.com/store/apps/details?id=pl.solidexplorer2"
                )
                
                AppRecommendation(
                    name: "MiXplorer",
                    description: "支持 HTTP 和 FTP 服务",
                    url: "https://mixplorer.com/"
                )
                
                AppRecommendation(
                    name: "Primitive FTPd",
                    description: "简单的 FTP/SFTP 服务器",
                    url: "https://play.google.com/store/apps/details?id=org.primftpd"
                )
            }
        }
        .padding()
    }
}

struct AppRecommendation: View {
    let name: String
    let description: String
    let url: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(name)
                    .font(.system(size: 13, weight: .medium))
                
                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("查看") {
                if let url = URL(string: url) {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.link)
        }
    }
}

#Preview {
    WiFiConnectionView()
}
