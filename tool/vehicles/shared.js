const W = 240, H = 160;
const shadow = `<ellipse cx="120" cy="138" rx="96" ry="9" fill="#1A2440" opacity=".12"/>`;
const wheel = (x, r = 17) => `
  <circle cx="${x}" cy="124" r="${r}" fill="#20232B"/>
  <circle cx="${x}" cy="124" r="${r * 0.55}" fill="#9AA3B2"/>
  <circle cx="${x}" cy="124" r="${r * 0.22}" fill="#5D6575"/>`;
const svg = (body) => `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">${shadow}${body}</svg>`;

module.exports = {
  mototaxi: svg(`
    <!-- rueda trasera y delantera -->
    ${wheel(62, 22)} ${wheel(182, 22)}
    <!-- basculante y horquilla -->
    <path d="M62 124 L104 104" stroke="#3B4252" stroke-width="7" stroke-linecap="round"/>
    <path d="M182 124 L164 70" stroke="#3B4252" stroke-width="7" stroke-linecap="round"/>
    <!-- carenado / tanque -->
    <path d="M86 98 C92 78 118 72 146 74 L166 80 C160 96 146 106 124 108 L96 108 Z" fill="#0B4FC4"/>
    <path d="M118 76 C126 66 144 64 156 70 L150 80 C140 76 128 76 118 80 Z" fill="#2F6EDB"/>
    <!-- motor -->
    <rect x="98" y="100" width="34" height="18" rx="5" fill="#5D6575"/>
    <rect x="104" y="104" width="22" height="10" rx="3" fill="#7C8596"/>
    <!-- sillín -->
    <path d="M72 84 C78 76 102 74 116 78 L114 86 C100 84 84 86 74 90 Z" fill="#20232B"/>
    <!-- guardabarro trasero -->
    <path d="M40 106 C46 92 66 88 80 94" stroke="#0B4FC4" stroke-width="7" fill="none" stroke-linecap="round"/>
    <!-- manubrio y farol -->
    <path d="M160 66 L172 50 L184 50" stroke="#20232B" stroke-width="6" fill="none" stroke-linecap="round" stroke-linejoin="round"/>
    <path d="M168 72 L186 72 L182 84 L168 82 Z" fill="#FFC93C"/>
    <!-- escape -->
    <path d="M70 116 L112 116" stroke="#9AA3B2" stroke-width="6" stroke-linecap="round"/>
  `),
  taxi: svg(`
    <!-- techo y letrero -->
    <rect x="98" y="34" width="44" height="14" rx="4" fill="#20232B"/>
    <text x="120" y="45" font-family="Arial, sans-serif" font-weight="700" font-size="10" fill="#FFC93C" text-anchor="middle">TAXI</text>
    <!-- carrocería -->
    <path d="M26 112 L26 94 C26 86 32 82 40 80 L70 76 L92 54 C96 50 102 48 108 48 L152 48 C160 48 166 52 170 58 L186 78 L206 82 C214 84 218 90 218 98 L218 112 C218 118 214 120 208 120 L32 120 C28 120 26 118 26 112 Z" fill="#FFC93C"/>
    <path d="M26 104 L218 104 L218 112 C218 118 214 120 208 120 L32 120 C28 120 26 118 26 112 Z" fill="#E8A800"/>
    <!-- ventanas -->
    <path d="M78 78 L98 58 C100 56 103 55 106 55 L124 55 L124 78 Z" fill="#BFD6F6"/>
    <path d="M132 55 L150 55 C155 55 159 57 162 61 L175 78 L132 78 Z" fill="#BFD6F6"/>
    <!-- franja damero -->
    <g fill="#20232B">
      ${[0,1,2,3,4,5,6,7,8,9,10,11].map(i => `<rect x="${44 + i * 13}" y="${i % 2 ? 90 : 96}" width="6.5" height="6"/>`).join('')}
    </g>
    <!-- farolas -->
    <rect x="206" y="88" width="12" height="8" rx="3" fill="#FFF4C2"/>
    <rect x="26" y="88" width="9" height="8" rx="3" fill="#E5484D"/>
    <!-- manija -->
    <rect x="114" y="84" width="12" height="3" rx="1.5" fill="#B37F00"/>
    ${wheel(66)} ${wheel(176)}
  `),
  colectivo: svg(`
    <!-- van blanca con franja azul -->
    <path d="M20 112 L20 52 C20 44 26 38 34 38 L158 38 C168 38 176 42 182 50 L210 84 C216 86 220 92 220 100 L220 112 C220 118 216 120 210 120 L28 120 C23 120 20 117 20 112 Z" fill="#F4F6FA"/>
    <path d="M20 112 L20 52 C20 44 26 38 34 38 L158 38 C168 38 176 42 182 50 L210 84 C216 86 220 92 220 100 L220 112 C220 118 216 120 210 120 L28 120 C23 120 20 117 20 112 Z" fill="none" stroke="#C9D1DD" stroke-width="2"/>
    <rect x="20" y="92" width="200" height="10" fill="#0B4FC4"/>
    <!-- ventanas -->
    <rect x="32" y="48" width="34" height="28" rx="5" fill="#BFD6F6"/>
    <rect x="72" y="48" width="34" height="28" rx="5" fill="#BFD6F6"/>
    <rect x="112" y="48" width="34" height="28" rx="5" fill="#BFD6F6"/>
    <path d="M152 48 L164 48 C168 48 172 50 175 54 L192 78 L152 78 Z" fill="#BFD6F6"/>
    <!-- puerta corrediza -->
    <rect x="110" y="44" width="1.5" height="60" fill="#C9D1DD"/>
    <rect x="208" y="98" width="12" height="8" rx="3" fill="#FFF4C2"/>
    <rect x="20" y="96" width="8" height="8" rx="3" fill="#E5484D"/>
    ${wheel(62)} ${wheel(178)}
  `),
  transpadilla: svg(`
    <!-- bus urbano -->
    <rect x="16" y="34" width="208" height="86" rx="14" fill="#0E7490"/>
    <rect x="16" y="98" width="208" height="22" rx="0" fill="#0B5E75"/>
    <rect x="16" y="106" width="208" height="14" rx="10" fill="#0B5E75"/>
    <rect x="16" y="34" width="208" height="12" rx="10" fill="#14899F"/>
    <!-- ventanas -->
    ${[0,1,2,3].map(i => `<rect x="${28 + i * 40}" y="52" width="32" height="30" rx="5" fill="#CDEEF5"/>`).join('')}
    <path d="M192 52 L208 52 C212 52 214 55 214 58 L214 92 L192 92 Z" fill="#CDEEF5"/>
    <!-- puerta -->
    <rect x="192" y="52" width="1.5" height="56" fill="#0B5E75"/>
    <rect x="212" y="100" width="12" height="8" rx="3" fill="#FFF4C2"/>
    <rect x="30" y="88" width="56" height="6" rx="3" fill="#FFC93C"/>
    ${wheel(58)} ${wheel(184)}
  `),
  intermunicipal: svg(`
    <!-- bus de carretera -->
    <path d="M14 112 L14 46 C14 38 20 32 28 32 L196 32 C210 32 220 40 222 54 L226 96 L226 112 C226 118 222 120 216 120 L22 120 C17 120 14 117 14 112 Z" fill="#FFFFFF"/>
    <path d="M14 112 L14 46 C14 38 20 32 28 32 L196 32 C210 32 220 40 222 54 L226 96 L226 112 C226 118 222 120 216 120 L22 120 C17 120 14 117 14 112 Z" fill="none" stroke="#C9D1DD" stroke-width="2"/>
    <!-- ventanal continuo -->
    <path d="M24 44 L200 44 C208 44 213 50 214 58 L216 76 L24 76 Z" fill="#1F2F4D"/>
    ${[0,1,2,3,4].map(i => `<rect x="${62 + i * 32}" y="44" width="2" height="32" fill="#FFFFFF" opacity=".6"/>`).join('')}
    <!-- franjas -->
    <path d="M14 84 L226 84 L226 92 L14 92 Z" fill="#0B4FC4"/>
    <path d="M14 96 L226 96 L226 100 L14 100 Z" fill="#FFC93C"/>
    <rect x="214" y="104" width="12" height="7" rx="3" fill="#FFF4C2"/>
    ${wheel(60)} ${wheel(96, 16)} ${wheel(188)}
  `),
};
