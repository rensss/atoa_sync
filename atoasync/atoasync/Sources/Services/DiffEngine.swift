import Foundation
import Combine

final class DiffEngine: Sendable {
    static let shared = DiffEngine()
    
    private init() {}
    
    func compare(deviceFiles: [FileInfo], localFiles: [FileInfo], useHash: Bool = false) async -> DiffResult {
        let deviceDict = Dictionary(uniqueKeysWithValues: deviceFiles.map { ($0.relativePath, $0) })
        let localDict = Dictionary(uniqueKeysWithValues: localFiles.map { ($0.relativePath, $0) })
        
        var newFiles: [FileInfo] = []
        var modifiedFiles: [FileInfo] = []
        var unchangedFiles: [FileInfo] = []
        var deletedFiles: [FileInfo] = []
        
        for (path, deviceFile) in deviceDict {
            if let localFile = localDict[path] {
                if self.hasChanged(device: deviceFile, local: localFile, useHash: useHash) {
                    modifiedFiles.append(deviceFile)
                } else {
                    unchangedFiles.append(deviceFile)
                }
            } else {
                newFiles.append(deviceFile)
            }
        }
        
        for (path, localFile) in localDict {
            if deviceDict[path] == nil {
                deletedFiles.append(localFile)
            }
        }
        
        return DiffResult(
            newFiles: newFiles.sorted { $0.relativePath < $1.relativePath },
            modifiedFiles: modifiedFiles.sorted { $0.relativePath < $1.relativePath },
            deletedFiles: deletedFiles.sorted { $0.relativePath < $1.relativePath },
            unchangedFiles: unchangedFiles.sorted { $0.relativePath < $1.relativePath }
        )
    }
    
    private func hasChanged(device: FileInfo, local: FileInfo, useHash: Bool) -> Bool {
        if useHash, let deviceHash = device.hash, let localHash = local.hash {
            return deviceHash != localHash
        }
        
        if device.size != local.size {
            return true
        }
        
        let timeDifference = abs(device.modified.timeIntervalSince(local.modified))
        return timeDifference > 2
    }
    
    func filterDiffResult(_ result: DiffResult, searchText: String, fileTypes: Set<FileType>, diffTypes: Set<DiffType>) -> DiffResult {
        var newFiles = result.newFiles
        var modifiedFiles = result.modifiedFiles
        var deletedFiles = result.deletedFiles
        var unchangedFiles = result.unchangedFiles
        
        if !searchText.isEmpty {
            newFiles = filterBySearch(newFiles, searchText: searchText)
            modifiedFiles = filterBySearch(modifiedFiles, searchText: searchText)
            deletedFiles = filterBySearch(deletedFiles, searchText: searchText)
            unchangedFiles = filterBySearch(unchangedFiles, searchText: searchText)
        }
        
        if !fileTypes.isEmpty {
            newFiles = filterByFileType(newFiles, fileTypes: fileTypes)
            modifiedFiles = filterByFileType(modifiedFiles, fileTypes: fileTypes)
            deletedFiles = filterByFileType(deletedFiles, fileTypes: fileTypes)
            unchangedFiles = filterByFileType(unchangedFiles, fileTypes: fileTypes)
        }
        
        if !diffTypes.contains(.new) {
            newFiles = []
        }
        if !diffTypes.contains(.modified) {
            modifiedFiles = []
        }
        if !diffTypes.contains(.deleted) {
            deletedFiles = []
        }
        if !diffTypes.contains(.unchanged) {
            unchangedFiles = []
        }
        
        return DiffResult(
            newFiles: newFiles,
            modifiedFiles: modifiedFiles,
            deletedFiles: deletedFiles,
            unchangedFiles: unchangedFiles
        )
    }
    
    private func filterBySearch(_ files: [FileInfo], searchText: String) -> [FileInfo] {
        return files.filter { file in
            file.relativePath.localizedCaseInsensitiveContains(searchText) ||
            file.path.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private func filterByFileType(_ files: [FileInfo], fileTypes: Set<FileType>) -> [FileInfo] {
        return files.filter { file in
            fileTypes.contains(FileType.from(path: file.path))
        }
    }
    
    @MainActor
    func buildFileTree(from files: [FileInfo]) -> [FileTreeNode] {
        // Use a wrapper node to hold the root level children
        // This avoids the value-type copy issue with dictionaries
        let rootContainer = FileTreeNode(name: "", path: "", isDirectory: true)
        
        for file in files {
            let components = file.relativePath.split(separator: "/").map(String.init)
            var currentNode = rootContainer
            
            for (index, component) in components.enumerated() {
                let isLast = index == components.count - 1
                
                if currentNode.children[component] == nil {
                    let node = FileTreeNode(
                        name: component,
                        path: file.path,
                        isDirectory: !isLast || file.isDirectory,
                        fileInfo: isLast ? file : nil
                    )
                    currentNode.children[component] = node
                }
                
                if !isLast {
                    currentNode = currentNode.children[component]!
                }
            }
        }
        
        return rootContainer.childrenArray
    }
}

@MainActor
class FileTreeNode: Identifiable, ObservableObject {
    let id = UUID()
    let name: String
    let path: String
    let isDirectory: Bool
    let fileInfo: FileInfo?
    @Published var children: [String: FileTreeNode]
    @Published var isExpanded: Bool
    @Published var isSelected: Bool
    
    init(name: String, path: String, isDirectory: Bool, fileInfo: FileInfo? = nil) {
        self.name = name
        self.path = path
        self.isDirectory = isDirectory
        self.fileInfo = fileInfo
        self.children = [:]
        self.isExpanded = false
        self.isSelected = false
    }
    
    var childrenArray: [FileTreeNode] {
        return Array(children.values).sorted { node1, node2 in
            if node1.isDirectory && !node2.isDirectory {
                return true
            } else if !node1.isDirectory && node2.isDirectory {
                return false
            }
            return node1.name < node2.name
        }
    }
    
    var icon: String {
        if isDirectory {
            return isExpanded ? "folder.fill" : "folder"
        } else {
            return FileType.from(path: path).icon
        }
    }
}
