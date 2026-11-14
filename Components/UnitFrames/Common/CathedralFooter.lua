local Addon, ns = ...
if not ns.IsForever then return end
ns.API.CreateCathedralFooterTextures = function(art, frame, texturePath, width, height)
	local extension = 160 * (height / 105 - width / 789)
	local texture = art:CreateTexture(nil, "ARTWORK", nil, 0)
	local uv = { 0, 1, 0, 1 }
	texture:SetTexture(texturePath, "CLAMP", "CLAMP")
	texture:SetTexCoord(unpack(uv))
	texture:SetSize(width + 2 * extension, height)
	texture:SetPoint("CENTER", frame, "CENTER")
	return { { texture, "-crypt-skull-tot", uv } }
end
