--[[
  Involute Gear: Effect of Profile Shift
  Parametric gear pair for 3D printing, written in Lua for IceSL (https://icesl.loria.fr)

  Case Study "Cyber-Physical Production Systems using Additive Manufacturing"
  Technische Hochschule Deggendorf, 2024
  Group 17: Bennet Kurian, Sarath Satheesh, Sajin Saji
  Advisor: Prof. Dr.-Ing. Stefan Scherbarth

  Open this file in IceSL, adjust the parameters in the "Tweaks" panel,
  and the gear pair, pins and stand update live. Export as STL or G-code.
]]

---------------------------------------------- User Interface ----------------------------------------------

-- Input parameters of Involute Gear
z1 = ui_numberBox("Number Of Teeth On Gear 1", 15)                          -- Number of teeth in Gear 1
z2 = ui_numberBox("Number Of Teeth On Gear 2 ", 18)                         -- Number of teeth in Gear 2
m = ui_scalarBox("Module Of Both Gears in mm", 6, 2)                        -- Gear module
alpha = ui_scalarBox("Pressure Angle of gears in degree ", 20, 0.1)         -- Pressure angle in degrees
h_a_coefficient = ui_scalarBox("Addendum Height Factor", 1.0, 0.1)          -- Addendum height factor
h_f_coefficient = ui_scalarBox("Dedendum Height Factor", 1.25, 0.1)         -- Dedendum height factor
i = ui_scalarBox("Rotation of Gears ", 0, 10)                               -- Rotation of both gears (deg)
Face_width = ui_numberBox("Face Width of Gear in mm", 20)                   -- Gear face width
handle_height = ui_numberBox("Handle height of Gear in mm", 20)             -- Handle height
rho_f_p = ui_scalar("Root Radius Coefficient", 0.38, 0.1, 1)                -- Root radius coefficient
x1 = ui_scalar("Profile Shift Coefficient 1", 0.5, -1, 1)                   -- Profile shift factor 1
x2 = ui_scalar("Profile Shift Coefficient 2", -0.5, -1, 1)                  -- Profile shift factor 2
c_2_c_tolerance = ui_scalarBox("Center to center distance tolerance factor", 0, 0.1)
-- in order to adjust the centre-to-centre distance tolerance

---------------------------------------------- Geometry functions ------------------------------------------

-- Calculating Involute Curve
-- r_b is the base radius, inv_alpha is the involute angle, inv_c is the involute curve
inv_c = function(r_b, inv_alpha)
    inv1 = v(r_b * (math.sin(inv_alpha) - inv_alpha * math.cos(inv_alpha)),
             r_b * (math.cos(inv_alpha) + inv_alpha * math.sin(inv_alpha)))
    return inv1
end

-- Function of Rotation
Rotation = function(rotate, coordinate)
    R = v(math.cos(rotate) * coordinate.x + math.sin(rotate) * coordinate.y,
          math.cos(rotate) * coordinate.y - math.sin(rotate) * coordinate.x)
    return R
end

-- Assign function of angle of involute in roll_angle_psi
roll_angle_psi = function(psi_b, psi_a)
    R_a = (math.sqrt((psi_a * psi_a - psi_b * psi_b) / (psi_b * psi_b)))
    return R_a
end

-- Calculate the angle subtended by the gear tooth profile at a specified point
-- on the base circle or the entire circle
function Circle(a, b, r, angle)
    return v(a + r * math.cos(angle), b + r * math.sin(angle))
end

-- Function of Mirror (across the y-axis)
Mirror = function(coordinate)
    M = v(-coordinate.x, coordinate.y)
    return M
end

-- Function of Profile shift: slope between first and fifth profile points
Profile_slop = function(prof)
    P_s = ((prof[5].y - prof[1].y) / (prof[5].x - prof[1].x))
    return P_s
end

-- Function to calculate the pressure angle: the angle formed between the two sides of a gear tooth
function angle_gear(m, x, alpha, z)
    alpha = alpha * math.pi / 180
    al = (((math.pi * m / 2) + 2 * m * x * math.tan(alpha)) / (z * m / 2) + 2 * math.tan(alpha) - 2 * alpha)
    return al
end

-- Create a linear extrude by scaling and extruding a given profile in a specified direction
function extrude(profile, angle_deg, extrusion_direction, scaling_factors, z_steps)
    local n_points = #profile                   -- Number of points
    local angle_rad = angle_deg / 180 * math.pi -- Convert angle from degrees to radian
    local vertices = {}                         -- Table to hold the vertices of the extruded shape

    for j = 0, z_steps - 1 do                   -- Loop over each step in the extrusion
        local phi = angle_rad * j / (z_steps - 1)                                       -- Rotation angle for this z step
        local vectordirection = extrusion_direction * j / (z_steps - 1)                 -- Position shift for this step
        local scalefactor = (scaling_factors - v(1, 1, 1)) * (j / (z_steps - 1)) + v(1, 1, 1) -- Scaling factor for this step
        for i = 1, n_points - 1 do              -- Loop over each point in the profile
            -- Calculate the position of the vertex after rotation, scaling and translation
            vertices[i + j * n_points] = v(vectordirection.x + scalefactor.x *
                                             (profile[i].x * math.cos(phi) - profile[i].y * math.sin(phi)),
                                           vectordirection.y + scalefactor.y *
                                             (profile[i].x * math.sin(phi) + profile[i].y * math.cos(phi)),
                                           vectordirection.z * scalefactor.z)
        end
        table.insert(vertices, vertices[1 + j * n_points]) -- Close the loop by connecting to the first vertex of this step
    end

    local vertex_sum_start = v(0, 0, 0)         -- Initialize sum of start vertices
    local vertex_sum_end = v(0, 0, 0)           -- Initialize sum of end vertices
    for i = 1, n_points - 1 do                  -- Sum up the start and end vertices
        vertex_sum_start = vertex_sum_start + vertices[i]
        vertex_sum_end = vertex_sum_end + vertices[i + n_points * (z_steps - 1)]
    end
    -- Calculate the average start and end vertices and insert
    table.insert(vertices, vertex_sum_start / (n_points - 1))
    table.insert(vertices, vertex_sum_end / (n_points - 1))

    local triangles = {}                        -- Table to hold the triangles of the extruded shape
    local k = 1                                 -- The indexing on the table with vertices starts with zero
    for j = 0, z_steps - 2 do                   -- Loop over each step in the extrusion
        for i = 0, n_points - 2 do              -- Loop over each point in the profile
            -- Define two triangles for each quad formed by consecutive points in consecutive steps
            triangles[k] = v(i, i + 1, i + n_points) + v(1, 1, 1) * n_points * j
            triangles[k + 1] = v(i + 1, i + n_points + 1, i + n_points) + v(1, 1, 1) * n_points * j
            k = k + 2
        end
    end
    for i = 0, n_points - 2 do                  -- Bottom cap
        triangles[k] = v(i + 1, i, n_points * z_steps)
        k = k + 1
    end
    for i = 0, n_points - 2 do                  -- Top cap: connect the last step to the end centre vertex
        triangles[k] = v(i + n_points * (z_steps - 1), i + 1 + n_points * (z_steps - 1), n_points * z_steps + 1)
        k = k + 1
    end
    return polyhedron(vertices, triangles)
end

-- Calculation of centre point of fillet radius between two profile points
function Fillet_radius(prof1, r_c, r_r)
    local slop = (prof1[2].y - prof1[1].y) / (prof1[2].x - prof1[1].x)
    local slop_ang = math.atan(slop)
    -- Finds the point on the involute curve that is parallel to the tangent at the specified profile point
    local x = prof1[1].x + r_c * math.cos(slop_ang + math.pi / 2)
    local y = prof1[1].y + r_c * math.sin(slop_ang + math.pi / 2)
    local d = (y - slop * x) / math.sqrt(slop * slop + 1)
    local th1 = math.asin(d / (r_c + r_r)) + slop_ang
    -- Returns v: vector representing the centre point of the fillet radius
    return v((r_c + r_r) * math.cos(th1), (r_c + r_r) * math.sin(th1))
end

-- Generates the full 2D profile of a gear (all teeth, involutes and root fillets)
function gear(z, m, alpha_rad, x, h_a_coeff, h_f_coeff, rho_f)
    local xy = {}
    c_c = x1 + x2
    cl = (c_c + c_2_c_tolerance) * m
    a = (z1 + z2) * m / 2 + cl                                -- Centre distance
    alpha_rad = alpha * math.pi / 180                         -- Pressure angle to radians
    D_p = z * m                                               -- Pitch diameter
    R_p = D_p / 2                                             -- Reference radius
    D_base = D_p * math.cos(alpha_rad)                        -- Base circle diameter
    r_b = D_base / 2                                          -- Base radius
    d_a = D_p + 2 * m * h_a_coefficient + 2 * m * x           -- Addendum diameter with profile shift
    r_a = d_a / 2                                             -- Addendum radius
    h_a = m * h_a_coefficient                                 -- Addendum height
    d_f = D_p - 2 * m * h_f_coefficient + 2 * m * x           -- Dedendum diameter with profile shift
    r_f = d_f / 2                                             -- Root radius
    h_r = m * h_f_coefficient                                 -- Dedendum height
    r_c = rho_f * m                                           -- Fillet root radius
    True_dia = math.sqrt(math.pow(D_p * math.sin(alpha_rad) - 2 * (h_a - (m * x) - h_r * (1 - math.sin(alpha_rad))), 2)
                         + D_base * D_base)                   -- True involute diameter
    True_rad = True_dia / 2                                   -- True involute radius
    tooth_angle = m * ((math.pi / 2) + 2 * x * math.tan(alpha_rad)) / R_p
                  + 2 * math.tan(alpha_rad) - 2 * alpha_rad   -- Angle between the two involute flanks
    Start_SOI = roll_angle_psi(r_b, True_rad)                 -- Start angle of involute curve
    End_SOI = roll_angle_psi(r_b, r_a)                        -- End angle of involute curve
    Points = 15                                               -- Number of points per curve segment

    local involute = {}                                       -- Involute curve points
    for i = 1, Points do
        involute[i] = inv_c(r_b, (Start_SOI + (End_SOI - Start_SOI) * i / Points))
    end
    Profile_slop_inv = Profile_slop(involute)                 -- Slope of profile from involute points
    pressure_angle = math.atan(Profile_slop_inv)              -- Pressure angle from the profile slope
    center_a = {}
    center_a[1] = Fillet_radius(involute, r_c, r_f)           -- Centre of the fillet circle
    Start_fillet = 2 * math.pi + math.atan(center_a[1].y / center_a[1].x)
    End_fillet = 3 * math.pi / 2 + pressure_angle             -- Start and end angle of the fillet

    for i = 1, z do                                           -- Loop over each tooth
        for j = 1, Points do                                  -- Left fillet, rotated per tooth
            xy[#xy + 1] = Rotation(2 * math.pi * i / z,
                Circle(center_a[1].x, center_a[1].y, r_c, (Start_fillet + (End_fillet - Start_fillet) * j / Points)))
        end
        for j = 1, Points do                                  -- Left involute, rotated per tooth
            xy[#xy + 1] = Rotation(2 * math.pi * i / z, inv_c(r_b, (Start_SOI + (End_SOI - Start_SOI) * j / Points)))
        end
        for j = Points, 1, -1 do                              -- Right involute: mirror + rotate, reverse order
            xy[#xy + 1] = Rotation(2 * math.pi * i / z, Rotation(tooth_angle, Mirror(
                inv_c(r_b, (Start_SOI + (End_SOI - Start_SOI) * j / Points)))))
        end
        for j = Points, 1, -1 do                              -- Right fillet: mirror + rotate, reverse order
            xy[#xy + 1] = Rotation(2 * math.pi * i / z, Rotation(tooth_angle, Mirror(
                Circle(center_a[1].x, center_a[1].y, r_c, (Start_fillet + (End_fillet - Start_fillet) * j / Points)))))
        end
    end
    xy[#xy + 1] = xy[1]                                       -- Close the profile
    return xy
end

---------------------------------------------- Assembly ----------------------------------------------------
-- NOTE: the lines up to "shaft1" (gear solids and rotations) are not shown in the user guide and were
-- reconstructed; everything from "shaft1" onwards is transcribed from the guide (Fig. 14 and 15).

Gear_1 = extrude(gear(z1, m, alpha, x1, h_a_coefficient, h_f_coefficient, rho_f_p),
                 0, v(0, 0, Face_width), v(1, 1, 1), 2)
r_f1 = r_f                                                    -- keep Gear 1 root radius for its pin and handle
Gear_2 = extrude(gear(z2, m, alpha, x2, h_a_coefficient, h_f_coefficient, rho_f_p),
                 0, v(0, 0, Face_width), v(1, 1, 1), 2)
r_f = r_f1

rotation_1 = rotate(0, 0, i)                                  -- user rotation from the Tweaks panel
rotation_2 = rotate(0, 0, 0)

shaft1 = ccylinder(5, 2 * Face_width)                         -- shaft hole of Gear 1
Gear1 = difference(Gear_1, shaft1)

-- Create assembly pins for gear 1
base = cylinder(r_f / 4, Face_width / 4)
h1 = cylinder(2, Face_width / 4)
base = difference(base, h1)
p1 = cylinder(4.9, 1.3 * Face_width)
p2 = cylinder(2.5, 1.3 * Face_width)
p = difference(p1, p2)
pin = union(base, p)

handle = translate(r_f - 0.1 * z1 * m, 0, 0) * cylinder(z1 * m / 15, handle_height)
Gear1 = union(Gear1, handle)

-- place the pin and Gear 1 in the model
emit(translate(0, 0, -1.25 * Face_width) * pin)
emit(translate(80, -15, 0) * rotation_2 * rotation_1 * Gear1, 7)

-- creating Gear 2 which will then mesh with Gear 1
shaft2 = ccylinder(5, 2 * Face_width)                         -- shaft hole of Gear 2
Gear2 = difference(Gear_2, shaft2)                            -- (reconstructed)
emit(translate(0, a, 0) * rotate(0, 0, -i * z1 / z2 + 180 / z2) * Gear2, 2) -- (reconstructed: meshing phase)

-- place a pin assembly for Gear 2
emit(translate(0, a, -1.25 * Face_width) * pin)

-- Create a stand for holding the pins
stand = translate(0, a / 2, -25) * cube(r_f * 0.45, a * 0.95, Face_width / 4)
stand = difference(stand, translate(0, a / 4, -25) * p2)
stand = difference(stand, translate(0, a * 0.75, -25) * p2)
emit(stand)
