namespace split_color_weave_2 {


texture2D tex <pooled = true;> { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA16F; };
sampler2D buffer { Texture = tex; };

texture2D texLinear : COLOR;
sampler2D samLinear { Texture = texLinear; SRGBTexture = false; };

float4 blur(const float2 uv, const float2 xy) {
    const float2 g = ceil(xy) * float2(1.0 / 1920.0, 1.0 / 1080.0) * 1.6;
    float weightSum = 4.0;
    float4 color = tex2D(buffer, uv) * weightSum;
    const int end = xy.x ? 10 : 6;
    for (int i = 1; i < end; i++) {
        float2 j = float(i) * g;
        const float e = 1.0 / (i * i);
        color += tex2D(buffer, uv + j) * e;
        color += tex2D(buffer, uv - j) * e;
        weightSum += 2.0 * e;
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
    const float3 gc3 = color * 1.5;
    const float3 max3 = min(1.0, gc3);
    const float3 rest3 = (gc3 - max3) * 2.0;
    return float3x3(float3(max3.rg, rest3.b), float3(rest3.r, max3.gb), float3(max3.r, rest3.g, max3.b));
}

float4 PS0(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target {
    const float4 color = tex2D(samLinear, uv);
    return float4(pow(color.rgb, 2.2), color.a);
}

float4 PS(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target {
    const bool flag = pos.x % 2 == pos.y % 2;
    const float4 color = blur(uv, flag ? float2(0.0, BUFFER_RCP_HEIGHT) : float2(BUFFER_RCP_WIDTH, 0.0));
    const int mod3 = (flag ? pos.x : pos.y) % 3;
    const float3 res = mul(float3(mod3 == 0, mod3 == 1, mod3 == 2), getLightColor(color.rgb));
    return float4(pow(saturate(res), 1.0 / 2.2), color.a);
}

technique split_color_weave_2 <ui_label = "分色编织";> {
    pass {
        VertexShader = VS;
        PixelShader = PS0;
        RenderTarget = tex;
    }
    pass {
        VertexShader = VS;
        PixelShader = PS;
        SRGBWriteEnable = false;
    }
}


}