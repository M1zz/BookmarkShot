//
//  CloudKitSchemaSeeder.swift
//  밑줄 (BookmarkShot)
//
//  DEBUG 전용. 모델에 칸을 더했을 때 CloudKit 개발 스키마를 모델 그대로 만든다.
//  `-InitCloudKitSchema` 인자로 켜면 임시 저장소로 initializeCloudKitSchema() 를 돌리고 끝낸다 — 실제 저장소는 건드리지 않는다.
//  그다음 CloudKit Console 에서 Development → Production 으로 배포한다.
//

#if DEBUG
import CoreData
import SwiftData

enum CloudKitSchemaSeeder {
    static func runIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("-InitCloudKitSchema") else { return }
        guard let model = NSManagedObjectModel.makeManagedObjectModel(for: [Book.self, Quote.self]) else {
            print("CloudKitSchemaSeeder: 모델을 만들지 못했어요"); exit(1)
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("schema-seed.store")
        let description = NSPersistentStoreDescription(url: url)
        description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud.com.leeo.bookmarkshot")
        description.shouldAddStoreAsynchronously = false

        let container = NSPersistentCloudKitContainer(name: "SchemaSeed", managedObjectModel: model)
        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { _, error in
            if let error { print("CloudKitSchemaSeeder: 저장소 실패 \(error)"); exit(1) }
        }
        do {
            try container.initializeCloudKitSchema()
            print("CloudKitSchemaSeeder: 완료")
            exit(0)
        } catch {
            print("CloudKitSchemaSeeder: 실패 \(error)"); exit(1)
        }
    }
}
#endif
