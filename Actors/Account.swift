//
//  AccountsDemo.swift
//  Actors
//
//  Created by Dario Lencina on 9/26/15.
//  Copyright © 2015 dario. All rights reserved.
//

import Foundation
import Theater

enum AccountEvent {
    
    case BalanceChange
    
    case DidDeposit
    
    case DidWithdraw
    
    var toString : String {
        switch self {
        case .DidWithdraw: return "DidWithdraw";
        case .DidDeposit: return "DidDeposit";
        case .BalanceChange: return "BalanceChange";
        }
    }
    
}

public class Account : Actor {
    
    override public var description  : String {
        return " \(self.balance())"
    }
    
    var number : String = ""
    
    private var _balance : Double = 0 {
        didSet {
            if _balance != oldValue {
                NSNotificationCenter.defaultCenter().postNotificationName(AccountEvent.BalanceChange.toString, object: this)
            }
        }
    }
    
    public override func receive(msg: Message) {
        switch msg {
            
            case is SetAccountNumber:
                let w = msg as! SetAccountNumber
                self.number = w.accountNumber
                print("account number \(self.number)")
                break;
            case is Withdraw:
                let w = msg as! Withdraw
                self.sender!.tell(BankOpResult(sender: this, operationId: w.operationId, result: self.withdraw(w.ammount)))
                break;
            case is Deposit:
                let w = msg as! Deposit
                self.sender!.tell(BankOpResult(sender: this, operationId: w.operationId, result: self.deposit(w.ammount)))
                break;
            case is PrintBalance:
                print("Balance of \(number) is \(balance().get())")
                //self.sender!.tell(BankOpResult(sender: this, operationId: w.operationId, result: self.balance()))
                break;
            case is BankOpResult:
                let w = msg as! BankOpResult
                print("Account \(number) : \(w.operationId.UUIDString) \(w.result.description())")
                break;
            default:
                print("Unable to handle message")
        }
    }
    
    func withdraw(amount : Double) -> Try<Double> {
        if _balance >= amount {
            _balance = _balance - amount
            return Success(value : _balance)
        } else {
            return Failure(exception: NSError(domain: "Insufficient funds", code: 0, userInfo: nil))
        }
        
    }
    
    func deposit(amount : Double) -> Try<Double> {
        _balance = _balance + amount
        return Success(value : _balance)
    }
    
    func balance() -> Try<Double> {
        return Success(value: _balance)
    }
}
