//
//  MemoryUtility.swift
//  MetalDemo
//
//  Created by Peng on 2021/7/21.
//

import Foundation

public func memory_size<T>(type: T.Type) -> Int {
    return MemoryLayout<T>.size
}

public func memory_convert<T>(form rawPointer: UnsafeRawPointer, length: Int, type: T.Type) -> [T] {
    var p = pthread_mutex_t()
    pthread_mutex_lock(&p)
    
    let size =  MemoryLayout<T>.size
    let count = length / size
    let rawBuffer = rawPointer
    
    let typePointer = rawBuffer.bindMemory(to: T.self, capacity: count)
    let typeBuffer = UnsafeBufferPointer<T>(start: typePointer, count: count)
    
    let ts = [T](typeBuffer)
    
    pthread_mutex_unlock(&p)
    print("\(T.self) count is \(ts.count)")
    return ts
}
