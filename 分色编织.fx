texture2D tex : COLOR;
sampler2D buffer { Texture = tex; SRGBTexture = BUFFER_COLOR_FORMAT == "R8G8B8A8_UNORM_SRGB"; };

float3 blur(const float2 uv, const float2 xy) {
    const float es[8] = {1.7, 0.25, 0.1111, 0.0625, 0.04, 0.0278, 0.0278, 0.0278};
    const float2 g = ceil(xy) * float2(1.0 / 1920.0, 1.0 / 1080.0) * 1.6;
    float weightSum = es[0];
    float3 color = tex2D(buffer, uv).rgb * weightSum;
    const int end = 6 + (xy.x ? 2 : 0);
    for (int i = 1; i < end; i += 1) {
        float2 j = float(i) * g;
        color += tex2D(buffer, uv + j).rgb * es[i];
        color += tex2D(buffer, uv - j).rgb * es[i];
        weightSum += 2.0 * es[i];
    }
    color /= weightSum;
    return color;
}

void VS(in uint id : SV_VertexID, out float4 position : SV_Position, out float2 texcoord : TEXCOORD) {
    texcoord.x = (id == 2) ? 2.0 : 0.0;
    texcoord.y = (id == 1) ? 2.0 : 0.0;
    position = float4(texcoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

float3x3 getLightColor(const float3 color) {
    const float3 gc3 = color * 3.0;
    const float3 max3 = min(1.0, gc3);
    const float3 rest3 = gc3 - max3;
    return float3x3(float3(max3.r, rest3.gb * 0.5), float3(rest3.r * 0.5, max3.g, rest3.b * 0.5), float3(rest3.rg * 0.5, max3.b));
}

float3 PS(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target {
    const bool flag = pos.x % 2 == pos.y % 2;
    const float3 color = blur(uv, flag ? float2(0.0, BUFFER_RCP_HEIGHT) : float2(BUFFER_RCP_WIDTH, 0.0));
    const int mod3 = (flag ? pos.x : pos.y) % 3;
    const float3 res = mul(float3(mod3 == 0, mod3 == 1, mod3 == 2), getLightColor(color));
    return saturate(res);
}

technique split_color_weave {
    pass {
        VertexShader = VS;
        PixelShader = PS;
        SRGBWriteEnable = BUFFER_COLOR_FORMAT == "R8G8B8A8_UNORM_SRGB";
    }
}
