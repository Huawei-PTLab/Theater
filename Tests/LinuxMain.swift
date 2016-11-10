//
// Copyright (c) 2016 Huawei PT-Lab Open Source project authors.
// Licensed under Apache License v2.0
//
// LinuxMain.swift
// The entry of test for Linux platform
//


import XCTest
@testable import TheaterTests

XCTMain([
     testCase(SelectActorTests.allTests),
     testCase(TheaterTests.allTests),
     testCase(SupervisionTests.allTests),
])
