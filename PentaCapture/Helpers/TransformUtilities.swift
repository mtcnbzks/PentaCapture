//
//  TransformUtilities.swift
//  PentaCapture
//
//  Created by Mehmetcan Bozkuş on 9.11.2025.
//  Inspired by Apple's ARKit Face Tracking Sample
//

import simd
import CoreGraphics
import ARKit

// MARK: - SIMD Extensions for Transform Utilities

extension simd_float4x4 {
    /// Create a 4x4 matrix from CGAffineTransform
    /// Follows Apple's ARKit best practices for texture coordinate transformations
    ///
    /// Converts a 2D affine transform (3x3 matrix stored as 6 elements):
    /// ```
    /// [ a  b  0 ]     [ a  b  0  0 ]
    /// [ c  d  0 ]  -> [ c  d  0  0 ]
    /// [ tx ty 1 ]     [ 0  0  1  0 ]
    ///                 [ tx ty 0  1 ]
    /// ```
    ///
    /// - Parameter affineTransform: The 2D affine transform to convert
    init(_ affineTransform: CGAffineTransform) {
        self.init(
            simd_float4(Float(affineTransform.a), Float(affineTransform.b), 0, 0),
            simd_float4(Float(affineTransform.c), Float(affineTransform.d), 0, 0),
            simd_float4(0, 0, 1, 0),
            simd_float4(Float(affineTransform.tx), Float(affineTransform.ty), 0, 1)
        )
    }
    
    /// Extract euler angles from a transform matrix using quaternion conversion
    /// Per Apple Developer Documentation: simd_quaternion for reliable rotation extraction
    /// Returns angles in radians as SIMD3<Float>(pitch, yaw, roll)
    ///
    /// Convention (ARKit right-handed coordinate system):
    /// - x (pitch): Rotation around X-axis (up/down)
    /// - y (yaw): Rotation around Y-axis (left/right)  
    /// - z (roll): Rotation around Z-axis (tilt)
    var eulerAngles: SIMD3<Float> {
        // Convert matrix to quaternion (Apple's recommended approach)
        let quat = simd_quaternion(self)
        
        // Extract quaternion components
        // simd_quatf stores as (ix, iy, iz, r) where r is the real/scalar part
        let x = quat.imag.x
        let y = quat.imag.y
        let z = quat.imag.z
        let w = quat.real
        
        // Convert quaternion to Euler angles (ZYX convention for ARKit)
        // This is the standard robust conversion used in robotics and AR
        
        // Pitch (x-axis rotation)
        let sinp = 2.0 * (w * x - z * y)
        let pitch: Float
        if abs(sinp) >= 1 {
            // Use 90 degrees if out of range (gimbal lock)
            pitch = copysign(Float.pi / 2, sinp)
        } else {
            pitch = asin(sinp)
        }
        
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
    
    /// Extract euler angles from a transform matrix (legacy tuple format)
    /// Per Apple ARKit documentation: Right-handed coordinate system
    ///
    /// - Returns: Tuple of (yaw, pitch, roll) in radians
    func extractEulerAngles() -> (yaw: Float, pitch: Float, roll: Float) {
        let angles = self.eulerAngles
        return (yaw: angles.y, pitch: angles.x, roll: angles.z)
    }
    
    /// Extract the translation component from the transform matrix
    /// - Returns: Translation vector (x, y, z)
    var translation: simd_float3 {
        return simd_float3(columns.3.x, columns.3.y, columns.3.z)
    }
    
    /// Extract the forward direction vector (Z-axis)
    /// - Returns: Normalized forward vector
    var forwardVector: simd_float3 {
        return simd_normalize(simd_float3(columns.2.x, columns.2.y, columns.2.z))
    }
    
    /// Extract the up direction vector (Y-axis)
    /// - Returns: Normalized up vector
    var upVector: simd_float3 {
        return simd_normalize(simd_float3(columns.1.x, columns.1.y, columns.1.z))
    }
    
    /// Extract the right direction vector (X-axis)
    /// - Returns: Normalized right vector
    var rightVector: simd_float3 {
        return simd_normalize(simd_float3(columns.0.x, columns.0.y, columns.0.z))
    }
}

extension simd_float3 {
    /// Convert vector to Euler angles (yaw, pitch)
    /// Useful for gaze direction or look-at calculations
    ///
    /// - Returns: Tuple of (yaw, pitch) in radians
    func toEulerAngles() -> (yaw: Float, pitch: Float) {
        let normalized = simd_normalize(self)
        let yaw = atan2(normalized.x, -normalized.z)
        let pitch = asin(normalized.y)
        return (yaw: yaw, pitch: pitch)
    }
    
    /// Calculate angle between two vectors in radians
    /// - Parameter other: The other vector to compare
    /// - Returns: Angle in radians [0, π]
    func angle(to other: simd_float3) -> Float {
        let dot = simd_dot(simd_normalize(self), simd_normalize(other))
        return acos(max(-1.0, min(1.0, dot)))
    }
    
    /// Calculate angle between two vectors in degrees
    /// - Parameter other: The other vector to compare
    /// - Returns: Angle in degrees [0, 180]
    func angleDegrees(to other: simd_float3) -> Float {
        return angle(to: other) * 180.0 / .pi
    }
}

// MARK: - ARFaceAnchor Extensions

extension ARFaceAnchor {
    /// Get head pose information from the face anchor
    /// Per Apple ARKit Best Practices: Use camera-relative transforms
    ///
    /// - Parameter cameraTransform: Optional camera transform for relative calculations
    /// - Returns: HeadPose structure with comprehensive orientation data
    func getHeadPose(relativeTo cameraTransform: simd_float4x4? = nil) -> (yaw: Float, pitch: Float, roll: Float) {
        let faceTransform: simd_float4x4
        
        if let cameraTransform = cameraTransform {
            // Calculate camera-relative transform
            let inverseCameraTransform = simd_inverse(cameraTransform)
            faceTransform = simd_mul(inverseCameraTransform, self.transform)
        } else {
            // Use world-space transform
            faceTransform = self.transform
        }
        
        return faceTransform.extractEulerAngles()
    }
    
    /// Check if face is looking approximately forward
    /// - Parameter tolerance: Tolerance in degrees (default: 15°)
    /// - Returns: True if face is looking forward within tolerance
    func isLookingForward(tolerance: Float = 15.0) -> Bool {
        let pose = getHeadPose()
        let yawDegrees = abs(pose.yaw * 180.0 / .pi)
        let pitchDegrees = abs(pose.pitch * 180.0 / .pi)
        return yawDegrees < tolerance && pitchDegrees < tolerance
    }
}

// MARK: - Coordinate System Conversions

/// Utility functions for coordinate system conversions
/// Per Apple documentation: ARKit uses right-handed coordinate system
enum CoordinateSystemUtilities {
    
    /// Convert ARKit world coordinates to screen coordinates
    /// - Parameters:
    ///   - worldPosition: Position in ARKit world space
    ///   - viewMatrix: Camera view matrix
    ///   - projectionMatrix: Camera projection matrix
    ///   - viewportSize: Screen viewport size
    /// - Returns: Screen position (x, y) or nil if behind camera
    static func worldToScreen(
        worldPosition: simd_float3,
        viewMatrix: simd_float4x4,
        projectionMatrix: simd_float4x4,
        viewportSize: CGSize
    ) -> CGPoint? {
        // Transform to camera space
        let viewProjection = simd_mul(projectionMatrix, viewMatrix)
        let worldPos4 = simd_float4(worldPosition.x, worldPosition.y, worldPosition.z, 1.0)
        let clipSpace = simd_mul(viewProjection, worldPos4)
        
        // Check if behind camera
        guard clipSpace.w > 0 else { return nil }
        
        // Normalize to NDC [-1, 1]
        let ndc = simd_float3(
            clipSpace.x / clipSpace.w,
            clipSpace.y / clipSpace.w,
            clipSpace.z / clipSpace.w
        )
        
        // Convert to screen coordinates [0, viewport]
        let screenX = (ndc.x + 1.0) * 0.5 * Float(viewportSize.width)
        let screenY = (1.0 - ndc.y) * 0.5 * Float(viewportSize.height) // Flip Y
        
        return CGPoint(x: CGFloat(screenX), y: CGFloat(screenY))
    }
    
    /// Calculate distance between two transforms
    /// - Parameters:
    ///   - transform1: First transform matrix
    ///   - transform2: Second transform matrix
    /// - Returns: Euclidean distance between the translation components
    static func distance(between transform1: simd_float4x4, and transform2: simd_float4x4) -> Float {
        let pos1 = transform1.translation
        let pos2 = transform2.translation
        return simd_distance(pos1, pos2)
    }
}

