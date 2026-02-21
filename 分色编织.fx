#define gammacrt 2.2
#define gammalcd 2.5
#define lighter 0.38
#define wh float2(BUFFER_RCP_WIDTH, 0.0)
#define hw float2(0.0, BUFFER_RCP_HEIGHT)

texture2D texBuff <pooled = true;> { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA8; };
sampler2D buffer { Texture = texBuff; };

texture2D texDiff : COLOR;
sampler2D differ { Texture = texDiff; };

float3 getBrightColor(const float3 color) {
    return color * saturate(1.34 - 0.15 / color);
}

float3 getSameColor(const float3 color, const float2 uv, const float2 xy, const int3 flag) {
    const float3 scan0 = float3(flag.x == 0, flag.x == 1, flag.x == 2);
    const float3 scan2 = float3(flag.z == 0, flag.z == 1, flag.z == 2);
    const float3 colorBefore = tex2D(buffer, uv + xy).rgb * scan0 * lighter;
    const float3 colorAfter = tex2D(buffer, uv - xy).rgb * scan2 * lighter;
    return (getBrightColor(colorBefore) + getBrightColor(color) + getBrightColor(colorAfter)) / 3.0;
}

float3 blur(float3 c, const float2 uv, const float2 xy) {
    const float es[8] = {2.0, 0.25, 0.1111, 0.0625, 0.04, 0.0278, 0.0278, 0.0278};
    const float2 g = ceil(xy) * float2(1.0 / 1920.0, 1.0 / 1080.0) * 1.5;
    float weightSum = es[0];
    float3 color = c * weightSum;
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

float3 getFinalColor(float4 pos, float2 uv, int3 flag, float2 xy, float2 yx) {
    const float3 color = tex2D(buffer, uv).rgb;
    const float3 scan = float3(flag.y == 0, flag.y == 1, flag.y == 2);
    const float3 gammaColor = color;
    const float3 scanColor = gammaColor * scan * lighter;
    const float3 blurColor = blur(gammaColor, uv, xy) * scan * lighter;
    const float3 sameColor = getSameColor(scanColor, uv, yx, flag);
    const float3 addColor = blurColor + sameColor;
    const float3 finalColor = addColor * 510.0 / 53.0;
    return pow(finalColor, 1.0 / gammacrt);
}

float4 PS0(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target {
    float3 color = pow(tex2D(differ, uv).rgb, gammacrt);
    const float3 diffrgb = min(color, 1.0 - color);
    const float diff = min(diffrgb.x, min(diffrgb.y, diffrgb.z)) * 0.5;
    const int2 oddxy = pos.xy % 3;
    const int odd = pos.x % 2 == pos.y % 2 ? oddxy.x : oddxy.y;
    color += diff * (float3(odd == 0, odd == 1, odd == 2) * 3.0 - 1.0);
    color = pow(color, gammalcd / gammacrt);
    return float4(color, 1.0);
}

float4 PS(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target {
    const int3 flagX = int3((pos.y - 1) % 3, pos.y % 3, (pos.y + 1) % 3);
    const int3 flagY = int3((pos.x - 1) % 3, pos.x % 3, (pos.x + 1) % 3);
    return float4(pos.x % 2 == pos.y % 2 ? getFinalColor(pos, uv, flagX, wh, hw) : getFinalColor(pos, uv, flagY, hw, wh), 1.0);
}

technique split_color_weave {
    pass {
        VertexShader = VS;
        PixelShader = PS0;
        RenderTarget = texBuff;
    }
    pass {
        VertexShader = VS;
        PixelShader = PS;
    }
}
