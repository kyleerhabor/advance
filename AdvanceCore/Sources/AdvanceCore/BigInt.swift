//
//  File.swift
//  AdvanceCore
//
//  Created by Kyle Erhabor on 11/28/25.
//

@preconcurrency import BigInt

extension BInt {
  public func digitCount(base: Self) -> Int {
    var n = self
    var count = 1

    // n = 100, base = 10
    //
    //
    while n >= base {
      guard n % base == BInt.ZERO else { // Ambiguous use of 'ZERO'
        break
      }

      n /= base
      count += 1
    }

    return count
  }
}

// This re-defines BFraction to not simplify.
//
// https://github.com/leif-ibsen/BigInt/blob/8c6f93aa37504b7b1ba3954335b5548a19fbbd82/Sources/BigInt/BigFrac.swift
public struct BigFraction {
  public static let zero = Self(BInt.ZERO, BInt.ONE)
  public static let one = Self(BInt.ONE, BInt.ONE)

  public var numerator: BInt
  public var denominator: BInt

  public var isNegative: Bool {
    return self.numerator.isNegative
  }

  public var isZero: Bool {
    return self.numerator.isZero
  }

  public init(_ n: BInt, _ d: BInt) {
    precondition(d.isNotZero)
    self.numerator = n
    self.denominator = d
  }

  public init?(_ x: String) {
    guard let (m, e) = Self.parseString(x) else {
      return nil
    }
    if e < 0 {
      self.init(m, BInt.TEN ** -e)
    } else {
      self.init(m * (BInt.TEN ** e), BInt.ONE)
    }
  }

  public func asString() -> String {
    return self.numerator.asString() + "/" + self.denominator.asString()
  }

  public func asDecimalString(precision: Int, exponential: Bool = false) -> String {
    precondition(precision > 0)
    if self.isZero {
      return Self.displayString(BInt.ZERO, -precision, exponential)
    }
    let P = BInt.TEN ** precision
    var exp = 0
    var q = self.numerator.abs
    while q.quotientAndRemainder(dividingBy: self.denominator).quotient < P {
      q *= BInt.TEN
      exp -= 1
    }
    while q.quotientAndRemainder(dividingBy: self.denominator).quotient >= P {
      q /= BInt.TEN
      exp += 1
    }
    let x = q.quotientAndRemainder(dividingBy: self.denominator).quotient
    return Self.displayString(self.isNegative ? -x : x, exp, exponential)
  }

  public static func +(x: Self, y: Self) -> Self {
    if x.denominator == y.denominator {
      return Self(x.numerator + y.numerator, x.denominator)
    } else {
      return Self(x.numerator * y.denominator + y.numerator * x.denominator, x.denominator * y.denominator)
    }
  }

  /// Subtraction
  ///
  /// - Parameters:
  ///   - x: Minuend
  ///   - y: Subtrahend
  /// - Returns: `x - y`
  public static func -(x: Self, y: Self) -> Self {
    if x.denominator == y.denominator {
      return Self(x.numerator - y.numerator, x.denominator)
    } else {
      return Self(x.numerator * y.denominator - y.numerator * x.denominator, x.denominator * y.denominator)
    }
  }

  public static func ==(x: Self, y: Self) -> Bool {
    return x.numerator == y.numerator && x.denominator == y.denominator
  }

  static func parseString(_ s: String) -> (mantissa: BInt, exponent: Int)? {
    enum State {
      case start
      case inInteger
      case inFraction
      case startExponent
      case inExponent
    }
    var state: State = .start
    var digits = 0
    var expDigits = 0
    var exp = ""
    var scale = 0
    var val = ""
    var negValue = false
    var negExponent = false
    for c in s {
      switch c {
        case "0", "1", "2", "3", "4", "5", "6", "7", "8", "9":
          if state == .start {
            state = .inInteger
            digits += 1
            val.append(c)
          } else if state == .inInteger {
            digits += 1
            val.append(c)
          } else if state == .inFraction {
            digits += 1
            scale += 1
            val.append(c)
          } else if state == .inExponent {
            expDigits += 1
            exp.append(c)
          } else if state == .startExponent {
            state = .inExponent
            expDigits += 1
            exp.append(c)
          }
          break
        case ".":
          if state == .start || state == .inInteger {
            state = .inFraction
          } else {
            return nil
          }
          break
        case "E", "e":
          if state == .inInteger || state == .inFraction {
            state = .startExponent
          } else {
            return nil
          }
          break
        case "+":
          if state == .start {
            state = .inInteger
          } else if state == .startExponent {
            state = .inExponent
          } else {
            return nil
          }
          break
        case "-":
          if state == .start {
            state = .inInteger
            negValue = true
          } else if state == .startExponent {
            state = .inExponent
            negExponent = true
          } else {
            return nil
          }
          break
        default:
          return nil
      }
    }
    if digits == 0 {
      return nil
    }
    if (state == .startExponent || state == .inExponent) && expDigits == 0 {
      return nil
    }
    let w = negValue ? -BInt(val)! : BInt(val)!
    let E = Int(exp)
    if E == nil && expDigits > 0 {
      return nil
    }
    let e = expDigits == 0 ? 0 : (negExponent ? -E! : E!)
    return (w, e - scale)
  }

  static func displayString(_ significand: BInt, _ exponent: Int, _ exponential: Bool) -> String {
    var s = significand.abs.asString()
    let precision = s.count
    if exponential {

      // exponential notation

      let exp = precision + exponent - 1
      if s.count > 1 {
        s.insert(".", at: s.index(s.startIndex, offsetBy: 1))
      }
      s.append("E")
      if exp > 0 {
        s.append("+")
      }
      s.append(exp.description)
    } else {

      // plain notation

      if exponent > 0 {
        if !significand.isZero {
          for _ in 0 ..< exponent {
            s.append("0")
          }
        }
      } else if exponent < 0 {
        if -exponent < precision {
          s.insert(".", at: s.index(s.startIndex, offsetBy: precision + exponent))
        } else {
          for _ in 0 ..< -(exponent + precision) {
            s.insert("0", at: s.startIndex)
          }
          s.insert(".", at: s.startIndex)
          s.insert("0", at: s.startIndex)
        }
      }
    }
    if significand.isNegative {
      s.insert("-", at: s.startIndex)
    }
    return s
  }
}

extension BigFraction: Sendable, Equatable {}

extension BigFraction: CustomStringConvertible {
  public var description: String {
    self.asString()
  }
}

