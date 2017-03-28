//
//  STDeferred.swift
//  STDeferred
//
//  Copyright © 2015 saiten. All rights reserved.
//

import Foundation
import Result

open class Deferred<T, E: Error> {
    
    // MARK: - Private properties
    
    fileprivate var successHandlers: [(T) -> Void] = []
    fileprivate var failureHandlers: [(E?) -> Void] = []
    fileprivate var completeHandlers: [(Result<T, E>?) -> Void] = []
    fileprivate var cancelHandlers: [((Void) -> Void)] = []
    
    // MARK: - Properties
    
    open fileprivate(set) var result: Result<T, E>?
    
    open fileprivate(set) var isCancelled: Bool = false
    
    open var isUnresolved: Bool {
        get {
            return self.result == nil && !self.isCancelled
        }
    }
    
    open var isRejected: Bool {
        get {
            if self.isCancelled {
                return true
            }
            
            guard let result = self.result else {
                return false
            }
            if case .failure(_) = result {
                return true
            } else {
                return false
            }
        }
    }
    
    open var isResolved: Bool {
        get {
            if self.isCancelled {
                return false
            }

            guard let result = self.result else {
                return false
            }
            if case .success(_) = result {
                return true
            } else {
                return false
            }
        }
    }
    
    open var resolve: (T) -> Deferred {
        get {
            return { (value: T) in
                return self._resolve(value)
            }
        }
    }
    
    open var reject: (E) -> Deferred {
        get {
            return { (error: E) in
                return self._reject(error)
            }
        }
    }
    
    // MARK: - Methods
    
    public init() {
    }
    
    public init(initClosure: (_ resolve: @escaping (T) -> Void, _ reject: @escaping (E) -> Void, _ cancel: @escaping (Void) -> Void) -> Void) {
        initClosure({ _ = self.resolve($0) },
                    { _ = self.reject($0) },
                    { self.cancel() })
    }
    
    public init(result: Result<T, E>) {
        self.result = result
    }
    
    public convenience init(value: T) {
        self.init(result: .success(value))
    }
    
    public convenience init(error: E) {
        self.init(result: .failure(error))
    }

//    deinit {
//        if let result = self.result {
//            NSLog("deferred deinit = " + result.description)
//        } else {
//            NSLog("deferred deinit")
//        }
//    }
    
    fileprivate func _resolve(_ value: T) -> Self {
        if self.isUnresolved {
            fire(.success(value))
        }
        return self;
    }
    
    fileprivate func _reject(_ error: E) -> Self {
        if self.isUnresolved {
            fire(.failure(error))
        }
        return self;
    }
    
    fileprivate func fire(_ result: Result<T, E>?) {
        self.result = result
        
        if let result = result {
            switch result {
            case .success(let value):
                for handler in successHandlers {
                    handler(value)
                }
            case .failure(let error):
                for handler in failureHandlers {
                    handler(error)
                }
            }
        } else {
            for handler in failureHandlers {
                handler(nil)
            }
        }
        
        for handler in completeHandlers {
            handler(result)
        }
        
        successHandlers.removeAll()
        failureHandlers.removeAll()
        completeHandlers.removeAll()
        cancelHandlers.removeAll()
    }
    
    @discardableResult
    open func cancel() -> Self {
        if self.isUnresolved {
            for handler in cancelHandlers {
                handler()
            }
            self.isCancelled = true
            fire(nil)
        }
        return self
    }
    
    @discardableResult
    open func success(_ handler: @escaping (T) -> Void) -> Self {
        if self.isResolved {
            handler(self.result!.value!)
        } else {
            successHandlers.append(handler)
        }
        return self
    }
    
    @discardableResult
    open func failure(_ handler: @escaping (E?) -> Void) -> Self {
        if self.isRejected {
            handler(self.result?.error)
        } else {
            failureHandlers.append(handler)
        }
        return self
    }
    
    @discardableResult
    open func canceller(_ handler: @escaping (Void) -> Void) -> Self {
        if self.isUnresolved {
            cancelHandlers.append(handler)
        }
        return self
    }
    
    @discardableResult
    open func complete(_ handler: @escaping (Result<T, E>?) -> Void) -> Self {
        if !self.isUnresolved {
            handler(result)
        } else {
            completeHandlers.append(handler)
        }
        return self
    }

    open func asVoid() -> Deferred<Void, E> {
        return self.then { (value) -> Void in }
    }

    // MARK: then

    @discardableResult
    open func then<T2>(_ handler: @escaping (T) -> Deferred<T2, E>) -> Deferred<T2, E> {
        return self.pipe { result -> Deferred<T2, E> in
            if let result = result {
                switch result {
                case .success(let value):
                    return handler(value)
                case .failure(let error):
                    return Deferred<T2, E>(error: error)
                }
            } else {
                return Deferred<T2, E>().cancel()
            }
        }
    }
    
    @discardableResult
    open func then<T2>(_ handler: @escaping (T) -> Result<T2, E>) -> Deferred<T2, E> {
        return self.then { value in
            return Deferred<T2, E>(result: handler(value))
        }
    }
    
    @discardableResult
    open func then<T2>(_ handler: @escaping (T) -> T2) -> Deferred<T2, E> {
        return self.then { value in
            return .success(handler(value))
        }
    }
    
    // MARK: pipe

    open func pipe<T2, E2>(_ handler: @escaping (Result<T, E>?) -> Result<T2, E2>?) -> Deferred<T2, E2> {
        return self.pipe { result -> Deferred<T2, E2> in
            if let result2 = handler(result) {
                return Deferred<T2, E2>(result: result2)
            } else {
                return Deferred<T2, E2>().cancel()
            }
        }
    }
    
    open func pipe<T2, E2>(_ handler: @escaping (Result<T, E>?) -> Deferred<T2, E2>) -> Deferred<T2, E2> {
        let deferred = Deferred<T2, E2>()
        
        deferred.canceller {
            self.cancel()
        }
        
        self.complete { result in
            let resultDeferred = handler(result)

            resultDeferred.complete { result in
                if let result = result {
                    switch result {
                    case .success(let value):
                        _ = deferred.resolve(value)
                    case .failure(let error):
                        _ = deferred.reject(error)
                    }
                }
            }
            deferred.canceller {
                resultDeferred.cancel()
            }
        }
        
        return deferred
    }
    
    @discardableResult
    open func sync(_ deferred: Deferred<T, E>) -> Self {
        deferred.complete { (result) in
            guard let result = result else {
                self.cancel()
                return
            }
            
            switch result {
            case .success(let value):
                _ = self.resolve(value)
            case .failure(let error):
                _ = self.reject(error)
            }
        }
        return self
    }
}

// MARK: - when

public func when<T, E>(_ deferreds: [Deferred<T, E>]) -> Deferred<Void, E> {
    let whenDeferred = Deferred<Void, E>()
    
    var unresolveCount = deferreds.count
    
    guard unresolveCount > 0 else {
        return whenDeferred.resolve()
    }
    
    for deferred in deferreds {
        deferred.complete { result in
            if let result = result {
                switch result {
                case .success:
                    unresolveCount -= 1
                    if unresolveCount == 0 {
                        _ = whenDeferred.resolve()
                    }
                case .failure(let error):
                    _ = whenDeferred.reject(error)
                }
            }
        }
        whenDeferred.canceller {
            deferred.cancel()
        }
    }
    
    return whenDeferred
}

public func when<T, E>(_ deferreds: [Deferred<T, E>]) -> Deferred<[T], E> {
    return when(deferreds).then { () -> [T] in
        return deferreds.map { $0.result!.value! }
    }
}

public func when<T, E>(_ deferreds: Deferred<T, E>...) -> Deferred<[T], E> {
    return when(deferreds)
}

public func when<E>(_ deferreds: Deferred<Void, E>...) -> Deferred<Void, E> {
    return when(deferreds)
}

public func when<T, U, E>(_ dt: Deferred<T, E>, _ du: Deferred<U, E>) -> Deferred<(T, U), E> {
    return when(dt.asVoid(), du.asVoid()).then { () -> (T, U) in
        return (dt.result!.value!, du.result!.value!)
    }
}

public func when<T, U, V, E>(_ dt: Deferred<T, E>, _ du: Deferred<U, E>, _ dv: Deferred<V, E>) -> Deferred<(T, U, V), E> {
    return when(dt.asVoid(), du.asVoid(), dv.asVoid()).then { () -> (T, U, V) in
        return (dt.result!.value!, du.result!.value!, dv.result!.value!)
    }
}

public func when<T, U, V, W, E>(_ dt: Deferred<T, E>, _ du: Deferred<U, E>, _ dv: Deferred<V, E>, _ dw: Deferred<W, E>) -> Deferred<(T, U, V, W), E> {
    return when(dt.asVoid(), du.asVoid(), dv.asVoid(), dw.asVoid()).then { () -> (T, U, V, W) in
        return (dt.result!.value!, du.result!.value!, dv.result!.value!, dw.result!.value!)
    }
}

