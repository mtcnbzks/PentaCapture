//
//  TransformUtilities.swift
//  PentaCapture
//
//  Created by Mehmetcan Bozkuş on 9.11.2025.
//

import simd

extension simd_float4x4 {
  /// Euler angles (pitch, yaw, roll) in radians from transform matrix via quaternion.
  /// ARKit right-handed: x=pitch (up/down), y=yaw (left/right), z=roll (tilt)
  var eulerAngles: SIMD3<Float> {
    let q = simd_quaternion(self)
    let (x, y, z, w) = (q.imag.x, q.imag.y, q.imag.z, q.real)

    let sinp = 2.0 * (w * x - z * y)
    let pitch: Float = abs(sinp) >= 1 ? copysign(.pi / 2, sinp) : asin(sinp)
    let yaw = atan2(2.0 * (w * y + z * x), 1.0 - 2.0 * (x * x + y * y))
    let roll = atan2(2.0 * (w * z + x * y), 1.0 - 2.0 * (z * z + x * x))

    return SIMD3<Float>(pitch, yaw, roll)
  }
}
