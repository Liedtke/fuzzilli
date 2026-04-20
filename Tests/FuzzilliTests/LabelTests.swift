import XCTest

@testable import Fuzzilli

class LabelTests: XCTestCase {
    func testWhileLoopLabel() {
        let fuzzer = makeMockFuzzer()
        let b = fuzzer.makeBuilder()

        let loopVar = b.loadInt(0)
        b.buildWhileLoop({
            return b.compare(loopVar, with: b.loadInt(10), using: .lessThan)
        }) { label in
            XCTAssertEqual(b.type(of: label), .jsLoopLabel)
            b.unary(.PostInc, loopVar)
            b.loopBreak(label)
        }

        let program = b.finalize()
        let actual = fuzzer.lifter.lift(program)
        let expected = """
            let v0 = 0;
            L3: while (v0 < 10) {
                v0++;
                break L3;
            }

            """
        XCTAssertEqual(actual, expected)
    }

    func testDoWhileLoopLabel() {
        let fuzzer = makeMockFuzzer()
        let b = fuzzer.makeBuilder()

        b.buildDoWhileLoop(
            do: { label in
                XCTAssertEqual(b.type(of: label), .jsLoopLabel)
                b.loopBreak(label)
            },
            while: {
                return b.loadBool(false)
            })

        let program = b.finalize()
        let actual = fuzzer.lifter.lift(program)
        let expected = """
            L0: do {
                break L0;
            } while (false)

            """
        XCTAssertEqual(actual, expected)
    }

    func testForLoopLabel() {
        let fuzzer = makeMockFuzzer()
        let b = fuzzer.makeBuilder()

        b.buildForLoop(
            i: { b.loadInt(0) }, { i in b.loadBool(true) }, { i in },
            { i, label in
                XCTAssertEqual(b.type(of: label), .jsLoopLabel)
                b.loopBreak(label)
            })

        let program = b.finalize()
        let actual = fuzzer.lifter.lift(program)
        let expected = """
            L5: for (let i1 = 0;;) {
                break L5;
            }

            """
        XCTAssertEqual(actual, expected)
    }

    func testForInLoopLabel() {
        let fuzzer = makeMockFuzzer()
        let b = fuzzer.makeBuilder()

        let obj = b.createObject(with: [:])
        b.buildForInLoop(obj) { i, label in
            XCTAssertEqual(b.type(of: label), .jsLoopLabel)
            b.loopBreak(label)
        }

        let program = b.finalize()
        let actual = fuzzer.lifter.lift(program)
        let expected = """
            L2: for (const v1 in {}) {
                break L2;
            }

            """
        XCTAssertEqual(actual, expected)
    }

    func testForOfLoopLabel() {
        let fuzzer = makeMockFuzzer()
        let b = fuzzer.makeBuilder()

        let obj = b.createArray(with: [])
        b.buildForOfLoop(obj) { i, label in
            XCTAssertEqual(b.type(of: label), .jsLoopLabel)
            b.loopBreak(label)
        }

        let program = b.finalize()
        let actual = fuzzer.lifter.lift(program)
        let expected = """
            L2: for (const v1 of []) {
                break L2;
            }

            """
        XCTAssertEqual(actual, expected)
    }

    func testRepeatLoopLabel() {
        let fuzzer = makeMockFuzzer()
        let b = fuzzer.makeBuilder()

        b.buildRepeatLoop(n: 10) { i, label in
            XCTAssertEqual(b.type(of: label), .jsLoopLabel)
            b.loopBreak(label)
        }

        let program = b.finalize()
        let actual = fuzzer.lifter.lift(program)
        let expected = """
            L1: for (let v0 = 0; v0 < 10; v0++) {
                break L1;
            }

            """
        XCTAssertEqual(actual, expected)
    }

    func testAllNestedLoopsLabels() {
        let fuzzer = makeMockFuzzer()
        let b = fuzzer.makeBuilder()

        b.buildWhileLoop({ b.loadBool(true) }) { whileLabel in
            b.loopContinue(whileLabel)
            b.loopBreak(whileLabel)

            b.buildForLoop(
                i: { b.loadInt(0) }, { i in b.loadBool(true) }, { i in },
                { i, forLabel in
                    b.loopContinue(whileLabel)
                    b.loopBreak(forLabel)

                    let obj = b.createObject(with: [:])
                    b.buildForInLoop(obj) { i, forInLabel in
                        b.loopContinue(forInLabel)
                        b.loopBreak(forLabel)

                        b.buildDoWhileLoop(
                            do: { doWhileLabel in
                                b.loopContinue(whileLabel)
                                b.loopBreak(doWhileLabel)

                                let arr = b.createArray(with: [])
                                b.buildForOfLoop(arr) { i, forOfLabel in
                                    b.loopContinue(forOfLabel)
                                    b.loopBreak(forInLabel)

                                    b.buildRepeatLoop(n: 10) { i, repeatLabel in
                                        b.loopContinue(whileLabel)
                                        b.loopBreak(repeatLabel)
                                    }
                                }
                            }, while: { b.loadBool(false) })
                    }
                })
        }

        let program = b.finalize()
        let actual = fuzzer.lifter.lift(program)
        let expected = """
            L1: while (true) {
                continue L1;
                break L1;
                L7: for (let i3 = 0;;) {
                    continue L1;
                    break L7;
                    L10: for (const v9 in {}) {
                        continue L10;
                        break L7;
                        L11: do {
                            continue L1;
                            break L11;
                            L14: for (const v13 of []) {
                                continue L14;
                                break L10;
                                L16: for (let v15 = 0; v15 < 10; v15++) {
                                    continue L1;
                                    break L16;
                                }
                            }
                        } while (false)
                    }
                }
            }

            """
        XCTAssertEqual(actual, expected)
    }

    func testAllNestedLoopsNoLabels() {
        let fuzzer = makeMockFuzzer()
        let b = fuzzer.makeBuilder()

        b.buildWhileLoop({ b.loadBool(true) }) {
            b.buildForLoop(
                i: { b.loadInt(0) }, { i in b.loadBool(true) }, { i in },
                { i in
                    let obj = b.createObject(with: [:])
                    b.buildForInLoop(obj) { i in
                        b.buildDoWhileLoop(
                            do: {
                                let arr = b.createArray(with: [])
                                b.buildForOfLoop(arr) { i in
                                    b.buildRepeatLoop(n: 10) { i in
                                        b.loadInt(42)
                                    }
                                }
                            }, while: { b.loadBool(false) })
                    }
                })
        }

        let program = b.finalize()
        let actual = fuzzer.lifter.lift(program)
        let expected = """
            while (true) {
                for (let i3 = 0;;) {
                    for (const v9 in {}) {
                        do {
                            for (const v13 of []) {
                                for (let v15 = 0; v15 < 10; v15++) {
                                }
                            }
                        } while (false)
                    }
                }
            }

            """
        XCTAssertEqual(actual, expected)
    }

    func testBlockStatementLabel() {
        let fuzzer = makeMockFuzzer()
        let b = fuzzer.makeBuilder()

        b.buildBlockStatement { label in
            XCTAssertEqual(b.type(of: label), .jsBlockLabel)
            b.blockBreak(label)
        }

        let program = b.finalize()
        let actual = fuzzer.lifter.lift(program)
        let expected = """
            L0: {
                break L0;
            }

            """
        XCTAssertEqual(actual, expected)
    }

    func testNestedBlockStatementLabels() {
        let fuzzer = makeMockFuzzer()
        let b = fuzzer.makeBuilder()

        b.buildBlockStatement { label1 in
            b.buildBlockStatement { label2 in
                b.blockBreak(label1)
                b.blockBreak(label2)
            }
        }

        let program = b.finalize()
        let actual = fuzzer.lifter.lift(program)
        let expected = """
            L0: {
                L1: {
                    break L0;
                    break L1;
                }
            }

            """
        XCTAssertEqual(actual, expected)
    }
}
