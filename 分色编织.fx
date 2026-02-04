uniform bool vertical <ui_label="vertical(竖向)";> = false;

#define gamma 2.2
#define gamma1 2.5
#define makea 510.0 / 53.0
#define bsigma 1.5609262985058092

texture2D texColor : COLOR;
sampler2D buffer { Texture = texColor; };

texture2D CacheTexX <pooled = true;> { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA8; };
sampler2D CacheX { Texture = CacheTexX; };

texture2D CacheTexY <pooled = true;> { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA8; };
sampler2D CacheY { Texture = CacheTexY; };

float3 tex2Dblur9fast(const float3 color, sampler2D tex, const float2 uv, const float2 xy) {
    const float denom = 0.5 / (bsigma * bsigma);
    const float w0 = 1.0;
    const float w1 = exp(-1.0 * denom);
    const float w2 = exp(-4.0 * denom);
    const float w3 = exp(-9.0 * denom);
    const float w4 = exp(-16.0 * denom);
    const float weightSum = 1.0 / (w0 + 2.0 * (w1 + w2 + w3 + w4));
    const float w12 = w1 + w2;
    const float w34 = w3 + w4;
    const float w12_ratio = w2/w12;
    const float w34_ratio = w4/w34;
    float3 sum = float3(0.0,0.0,0.0);
    sum += w34 * tex2D(tex, uv - (3.0 + w34_ratio) * xy).rgb;
    sum += w12 * tex2D(tex, uv - (1.0 + w12_ratio) * xy).rgb;
    sum += w0 * color;
    sum += w12 * tex2D(tex, uv + (1.0 + w12_ratio) * xy).rgb;
    sum += w34 * tex2D(tex, uv + (3.0 + w34_ratio) * xy).rgb;
    return sum * weightSum;
}

float3 getAndColorX(float4 pos, float2 uv) {
    const float3 color = tex2D(buffer, uv).rgb;
    const int zong3 = pos.y % 3;
    return pow(color, gamma1) * 0.5 * float3(zong3 == 0, zong3 == 1, zong3 == 2);
}

float3 getAndColorY(float4 pos, float2 uv) {
    const float3 color = tex2D(buffer, uv).rgb;
    const int heng3 = pos.x % 3;
    return pow(color, gamma1) * 0.5 * float3(heng3 == 0, heng3 == 1, heng3 == 2);
}

float3 getBrightColor(float3 andColor) {
    const float3 intensity = andColor * makea * 0.8;
    const float3 blurTemp =(1.0 / intensity - 1.0) / (0.255832 - 1.0);
    const float3 blurRatio = saturate(blurTemp);
    const float3 brightpass = andColor * blurRatio;
    return brightpass;
}

float3 blurh(float2 uv) {
    const float g = BUFFER_RCP_WIDTH * 1.6;
    float3 h = tex2D(CacheX, uv).rgb;
    float weightSum = 1.0;
    const int ox = 5 + (vertical ? 0 : 2);
    for (int i = 1; i < ox; i += 1) {
        float2 j = float2(float(i) * g, 0.0);
        h += tex2D(CacheX, uv + j).rgb;
        h += tex2D(CacheX, uv - j).rgb;
        weightSum += 2.0;
    }
    h /= weightSum;
    return h;
}

float3 blurv(float2 uv) {
    const float g = BUFFER_RCP_HEIGHT * 1.6;
    float3 h = tex2D(CacheY, uv).rgb;
    float weightSum = 1.0;
    const int oy = 5 + (vertical ? 2 : 0);
    for (int i = 1; i < oy; i += 1) {
        float2 j = float2(0.0, float(i) * g);
        h += tex2D(CacheY, uv + j).rgb;
        h += tex2D(CacheY, uv - j).rgb;
        weightSum += 2.0;
    }
    h /= weightSum;
    return h;
}

void VS(in uint id : SV_VertexID, out float4 position : SV_Position, out float2 texcoord : TEXCOORD)
{
	texcoord.x = (id == 2) ? 2.0 : 0.0;
	texcoord.y = (id == 1) ? 2.0 : 0.0;
	position = float4(texcoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

float4 PSX(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target {
    const float3 andColor = getAndColorX(pos, uv);
    return float4(getBrightColor(andColor), 1.0);
}

float4 PSY(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target {
    const float3 andColor = getAndColorY(pos, uv);
    return float4(getBrightColor(andColor), 1.0);
}

float3 getFinalColorX(float4 pos, float2 uv) {
    const float3 andColor = getAndColorX(pos, uv);
    const float3 brightpass = blurh(uv);
    const float3 blurBright = tex2Dblur9fast(brightpass, CacheX, uv, float2(0, BUFFER_RCP_HEIGHT));
    const float3 addColor = andColor + blurBright;
    const float maxrcp = gamma1 * 1.4 / max(addColor.r, max(addColor.g, addColor.b));
    const float make = min(maxrcp, makea);
    const float3 phosphorBbloom = addColor * make;
    return pow(phosphorBbloom, 1.0 / gamma);
}

float3 getFinalColorY(float4 pos, float2 uv) {
    const float3 andColor = getAndColorY(pos, uv);
    const float3 brightpass = blurv(uv);
    const float3 blurBright = tex2Dblur9fast(brightpass, CacheY, uv, float2(BUFFER_RCP_WIDTH, 0));
    const float3 addColor = andColor + blurBright;
    const float maxrcp = gamma1 * 1.4 / max(addColor.r, max(addColor.g, addColor.b));
    const float make = min(maxrcp, makea);
    const float3 phosphorBbloom = addColor * make;
    return pow(phosphorBbloom, 1.0 / gamma);
}

float4 PS1(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target {
    const float3 colorX = getFinalColorX(pos, uv);
    const float3 colorY = getFinalColorY(pos, uv);
    return pos.x % 2 == pos.y % 2 ? float4(colorX, 1.0) :float4(colorY, 1.0);
    
}

technique split_color_weave {
    pass {
        VertexShader = VS;
        PixelShader = PSX;
        RenderTarget = CacheTexX;
    }
    pass {
        VertexShader = VS;
        PixelShader = PSY;
        RenderTarget = CacheTexY;
    }
    pass {
        VertexShader = VS;
        PixelShader = PS1;
    }
}
