
const { norm } = require("./places");

const LOCAL_CUISINE = {
  China: /shanghainese|本帮|上海菜|chinese restaurant|中餐|jiangsu|zhejiang|cantonese|sichuan/i,
  Thailand: /thai|泰|pad thai|tom yum|som tam|isaan|boat noodle/i,
  Malaysia: /malay|nyonya|peranakan|hawker|nasi|laksa|char kway teow|mamak|kopitiam|satay|asam/i,
  Singapore: /hawker|hainanese|chicken rice|chilli crab|laksa|peranakan|kopitiam|satay/i,
  Indonesia: /indonesian|balinese|babi guling|nasi|satay|warung|bebek/i,
  Japan: /japanese|ramen|sushi|izakaya|udon|okonomiyaki|takoyaki|和食|拉面|寿司/i,
  "South Korea": /korean|bbq|kimchi|bibimbap|韩/i,
  Taiwan: /taiwanese|beef noodle|台湾|小吃|braised pork rice/i,
  "Hong Kong": /cantonese|dim sum|cha chaan teng|roast goose|wonton|茶餐厅|点心|粤/i,
  Vietnam: /vietnamese|pho|banh mi|bun cha|越南/i,
};

const NEEDS = [
  { kind: "museum", label: "Museum", words: /博物馆|美术馆|展览馆|museum|gallery|exhibition/i, fits: /museum|gallery|博物馆|美术馆|exhibit/i, food: false },
  { kind: "cafe", label: "Café", words: /咖啡馆|咖啡厅|咖啡店|café|cafe|coffee shop|coffee/i, fits: /caf[eé]|coffee|咖啡|tea house|茶馆/i, food: true },
  { kind: "brunch", label: "Brunch place", words: /brunch|早午餐/i, fits: /brunch|caf[eé]|breakfast|bakery|coffee|咖啡|早午餐/i, food: true },
  { kind: "local food", label: "Local restaurant", words: /本帮菜|上海菜|本地菜|当地菜|地道|shanghainese|local food|local restaurant|红烧肉|葱油拌面|泰国菜|泰式料理|thai food|马来菜|娘惹|nyonya|日本料理|韩国料理|越南菜|hawker|小贩中心/i,
    fits: /shanghainese|本帮|上海菜|local cuisine|local food|chinese restaurant|中餐|jiangsu|zhejiang/i, local: true, food: true },
  { kind: "street food", label: "Street food", words: /街头小吃|路边摊|小吃街|street food|food street|hawker stall/i,
    fits: /street food|food street|hawker|小吃|yaowarat|chinatown|night market|夜市|jalan alor|gurney/i, food: null,
    slots: "DN", hours: 1.5, icon: "food" },
  { kind: "dumplings", label: "Dumplings", words: /小笼包|小笼|生煎|汤包|饺子|xiaolongbao|xiao long bao|soup dumpling|dumpling|shengjian/i,
    fits: /dumpling|bao|小笼|生煎|汤包|饺子|shengjian|tang bao/i, food: true },
  { kind: "dessert", label: "Dessert", words: /甜品|甜点|dessert|糖水/i, fits: /dessert|甜品|sweet|cake|ice cream|bakery|糖水/i, food: true },
  { kind: "mall", label: "Shopping mall", words: /商场|购物中心|百货|shopping mall|\bmall\b/i, fits: /mall|plaza|shopping cent|department|商场|广场|百货/i, food: false },
  { kind: "night market", label: "Night market", words: /夜市|night market|pasar malam/i, fits: /night market|夜市|pasar malam|jodd fairs|ratchada|shilin|士林|raohe|饶河|temple street|ximending/i,
    food: null, slots: "N", hours: 2, icon: "shopping" },
  { kind: "floating market", label: "Floating market", words: /水上市场|floating market/i, fits: /floating market|水上市场|damnoen|amphawa/i, food: null,
    slots: "M", hours: 3, icon: "activity" },
  { kind: "rooftop bar", label: "Rooftop bar", words: /高空酒吧|天台酒吧|rooftop bar|sky bar|skybar/i, fits: /rooftop|sky ?bar|skywalk|observation|高空/i, food: null,
    slots: "EN", hours: 1.5, icon: "place" },
  { kind: "beach", label: "Beach", words: /海滩|沙滩|海边|beach|pantai/i, fits: /beach|海滩|沙滩|pantai|bay/i, food: false, slots: "MA", hours: 3, icon: "place" },
  { kind: "park", label: "Park", words: /公园|park\b/i, fits: /park|garden|公园|花园/i, food: false },
  { kind: "temple", label: "Temple", words: /寺庙|庙|temple|寺/i, fits: /temple|寺|庙|shrine|pagoda/i, food: false },
  { kind: "massage", label: "Massage / spa", words: /按摩|massage|\bspa\b|足疗|马杀鸡/i, fits: /massage|spa|按摩|足疗|reflexology/i, food: false,
    slots: "AE", hours: 1.5, icon: "activity" },
];
const CONDITIONAL = /(如果|万一|要是|假如|下雨|雨天|if it rains|in case|if it'?s raining|rainy|backup|备选|备用|plan b)/i;

function findNeeds(text, skip = []) {
  let t = norm(text);
  for (const [s, e] of skip) t = t.slice(0, s) + " ".repeat(Math.max(0, e - s)) + t.slice(e);
  return NEEDS.filter((n) => n.words.test(t)).map((n) => ({ ...n, conditional: CONDITIONAL.test(t) }));
}

function placeFits(place, need, city = "") {
  if (!place) return false;
  if (need.food !== null && need.food !== undefined && need.food !== (place.icon === "food")) return false;
  const text = [place.name, ...(place.tags || []), ...(place.aliases || [])].join(" ");
  if (need.local) {
    const country = String(city || place.city || "").split(",").pop().trim();
    const re = LOCAL_CUISINE[country] || (/shanghai/i.test(city) ? LOCAL_CUISINE.China : null);
    if (re && re.test(text)) return true;
  }
  if (need.kind === "mall" && place.icon === "shopping" && !/market|street|road|bazaar|路|街|市场|夜市/i.test(text)) return true;
  return need.fits.test(text);
}

const DIETARY = {
  Halal: /halal|muslim.?friendly|清真/i,
  Vegetarian: /vegetarian|素食|veg\b/i,
  Vegan: /\bvegan\b|全素/i,
  Kosher: /\bkosher\b/i,
  "Gluten-free": /gluten.?free|无麸质/i,
};

function matchesFoodPreference(place, foodPreference) {
  const re = DIETARY[String(foodPreference || "").trim()];
  if (!re || !place) return false;
  const text = [place.name, ...(place.tags || []), ...(place.aliases || [])].join(" ");
  return re.test(text);
}

function genericPlace(need) {
  const food = need.food === true || need.icon === "food";
  return {
    name: need.label, area: "", district: "", generic: true,
    icon: need.icon || (food ? "food" : "place"),
    slots: need.slots || (food ? (/caf[eé]|dessert|brunch/i.test(need.label) ? "BLA" : "LD") : "MA"),
    hours: need.hours || (food ? 1 : 1.5),
    aliases: [], tags: [], source: "generic", saved: null,
  };
}

module.exports = { NEEDS, findNeeds, placeFits, genericPlace, matchesFoodPreference };
