offset_of :: ($T: Type, $member: string) -> int {
  for type_info(T).members {
    if it.name == member {
      return it.offset_in_bytes;
    }
  }
  assert(false, "Type '%' does not have member '%'", T, member);
  return -1;
}

degrees_to_radians :: (deg: float) -> float {
  return deg * (TAU / 360.0);
}

radians_to_degrees :: (rad: float) -> float {
  return rad * (360.0 / TAU);
}

vector4_pack :: (v: Vector4) -> u32 {
  pack_channel :: inline (f: float) -> u32 {
    if f <= 0.0  return 0;
    if f >= 1.0  return 255;
    return cast(u32) (f * 255.0 + 0.5);
  }

  x := pack_channel(v.x);
  y := pack_channel(v.y);
  z := pack_channel(v.z);
  w := pack_channel(v.w);
  return (w << 24) | (z << 16) | (y << 8) | x;
}
