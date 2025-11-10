//
//  TransformUtilities.swift
//  PentaCapture
//
//  Created by Mehmetcan Bozkuş on 9.11.2025.
//

import simd

// MARK: - SIMD Extensions for Transform Utilities

extension simd_float4x4 {
    /// Extract euler angles from a transform matrix using quaternion conversion
    /// Returns angles in radians as SIMD3<Float>(pitch, yaw, roll)
    ///
    /// Convention (ARKit right-handed coordinate system):
    /// - x (pitch): Rotation around X-axis (up/down)
    /// - y (yaw): Rotation around Y-axis (left/right)
    /// - z (roll): Rotation around Z-axis (tilt)
    var eulerAngles: SIMD3<Float> {
        let quat = simd_quaternion(self)

        let x = quat.imag.x
        let y = quat.imag.y
        let z = quat.imag.z
        let w = quat.real

        // Pitch (x-axis rotation)
        let sinp = 2.0 * (w * x - z * y)
        let pitch: Float = abs(sinp) >= 1 ? copysign(Float.pi / 2, sinp) : asin(sinp)

        // Yaw (y-axis rotation)
        let siny_cosp = 2.0 * (w * y + z * x)
        let cosy_cosp = 1.0 - 2.0 * (x * x + y * y)
        let yaw = atan2(siny_cosp, cosy_cosp)

        // Roll (z-axis rotation)
        let sinr_cosp = 2.0 * (w * z + x * y)
        let cosr_cosp = 1.0 - 2.0 * (z * z + x * x)
        let roll = atan2(sinr_cosp, cosr_cosp)

        return SIMD3<Float>(pitch, yaw, roll)
    }
}

