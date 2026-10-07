-- Headless checks of the gear geometry. Run from the repo root:  lua tests/test_gear.lua
dofile("tests/icesl_stub.lua")
dofile("involute_gear_profile_shift.lua")

local failures = 0
local function check(cond, msg)
  print((cond and "PASS  " or "FAIL  ") .. msg)
  if not cond then failures = failures + 1 end
end

-- 1. The script builds the full assembly: 2 pins, 2 gears, 1 stand
check(#EMITTED == 5, "assembly emits 5 parts (got " .. #EMITTED .. ")")

-- 2. Profile structure, for several gear sizes and profile shifts
for _, case in ipairs({ { 15, 0.5 }, { 18, -0.5 }, { 25, 0.0 }, { 40, 0.3 } }) do
  local z, x = case[1], case[2]
  local prof = gear(z, m, alpha, x, h_a_coefficient, h_f_coefficient, rho_f_p)
  local label = string.format("z=%d, x=%+.1f: ", z, x)

  check(#prof == z * 4 * Points + 1, label .. "4 curve segments per tooth + closing point")
  check(prof[1].x == prof[#prof].x and prof[1].y == prof[#prof].y, label .. "profile is closed")

  local ok_nan, rmax = true, 0
  for _, p in ipairs(prof) do
    if p.x ~= p.x or p.y ~= p.y then ok_nan = false end
    rmax = math.max(rmax, math.sqrt(p.x ^ 2 + p.y ^ 2))
  end
  check(ok_nan, label .. "no NaN points")
  check(rmax <= r_a + 1e-6, label .. string.format("no point outside tip circle (max r = %.2f, r_a = %.2f)", rmax, r_a))

  -- tip diameter with profile shift: d_a = m*z + 2*m*(h_a + x)
  check(math.abs(d_a - (m * z + 2 * m * (h_a_coefficient + x))) < 1e-9, label .. "tip diameter formula")
end

-- 3. Centre distance follows the profile-shift rule a = m*(z1+z2)/2 + (x1+x2)*m
check(math.abs(a - (m * (z1 + z2) / 2 + (x1 + x2 + c_2_c_tolerance) * m)) < 1e-9, "centre distance with profile shift")

if failures > 0 then
  print(failures .. " check(s) failed"); os.exit(1)
end
print("All checks passed")
