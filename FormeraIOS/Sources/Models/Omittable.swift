import Foundation

/// Tri-state field for a PATCH body where "field absent" (leave as-is) and
/// "field explicitly null" (clear it) are different backend behaviors --
/// e.g. UpdateOrderInput.discountPercent: omitting the key leaves the
/// existing discount alone, but sending null clears it. A plain Optional can't
/// distinguish those once flattened into JSON, so the containing type's
/// encode(to:) switches on this explicitly instead.
enum Omittable<T> {
    case omit
    case value(T?)
}
