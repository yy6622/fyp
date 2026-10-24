// Voya — shared, real/verified default reference data for the Country
// Emergency Info admin pages (country-emergency.html list,
// country-emergency-form.html destination form, country-embassy-form.html
// per-embassy form).
//
// Police/ambulance/fire numbers are destination-only — the same regardless
// of a trip member's own nationality, which is why they're kept separate
// from embassy data below. Embassy contact details were sourced ONLY from
// each home country's own official Ministry of Foreign Affairs directory
// (never general knowledge, never a third-party site) — see each
// nationality's own notes in claude/session-2026-10-20-country-emergency-
// info-admin-and-firestore.md for exact sources. DEFAULT_EMBASSIES is a map
// of destinationKey -> homeCountryKey -> embassy so any number of
// nationalities' embassies can coexist per destination. Kept here only as
// a one-click starting point ("Fill with default values" / "Import missing
// defaults") — nothing here is written to Firestore without the
// signed-in admin explicitly clicking Save or Import.

export const DEFAULT_EMERGENCY_NUMBERS = {
  malaysia: {
    police: "999",
    ambulance: "999",
    fire: "999"
  },
  singapore: {
    police: "999",
    ambulance: "995",
    fire: "995"
  },
  indonesia: {
    police: "110",
    ambulance: "119",
    fire: "113"
  },
  thailand: {
    police: "191",
    ambulance: "1669",
    fire: "199"
  },
  vietnam: {
    police: "113",
    ambulance: "115",
    fire: "114"
  },
  philippines: {
    police: "911",
    ambulance: "911",
    fire: "911"
  },
  japan: {
    police: "110",
    ambulance: "119",
    fire: "119"
  },
  "south korea": {
    police: "112",
    ambulance: "119",
    fire: "119"
  },
  china: {
    police: "110",
    ambulance: "120",
    fire: "119"
  },
  "hong kong": {
    police: "999",
    ambulance: "999",
    fire: "999"
  },
  taiwan: {
    police: "110",
    ambulance: "119",
    fire: "119"
  },
  india: {
    police: "112",
    ambulance: "102",
    fire: "101"
  },
  australia: {
    police: "000",
    ambulance: "000",
    fire: "000"
  },
  "new zealand": {
    police: "111",
    ambulance: "111",
    fire: "111"
  },
  "united kingdom": {
    police: "999",
    ambulance: "999",
    fire: "999"
  },
  ireland: {
    police: "112",
    ambulance: "112",
    fire: "112"
  },
  france: {
    police: "17",
    ambulance: "15",
    fire: "18"
  },
  germany: {
    police: "110",
    ambulance: "112",
    fire: "112"
  },
  italy: {
    police: "113",
    ambulance: "118",
    fire: "115"
  },
  spain: {
    police: "112",
    ambulance: "112",
    fire: "112"
  },
  netherlands: {
    police: "112",
    ambulance: "112",
    fire: "112"
  },
  switzerland: {
    police: "117",
    ambulance: "144",
    fire: "118"
  },
  "united states": {
    police: "911",
    ambulance: "911",
    fire: "911"
  },
  canada: {
    police: "911",
    ambulance: "911",
    fire: "911"
  },
  "united arab emirates": {
    police: "999",
    ambulance: "998",
    fire: "997"
  },
  "saudi arabia": {
    police: "999",
    ambulance: "997",
    fire: "998"
  },
  turkey: {
    police: "112",
    ambulance: "112",
    fire: "112"
  },
  "south africa": {
    police: "10111",
    ambulance: "10177",
    fire: "10177"
  },
  brazil: {
    police: "190",
    ambulance: "192",
    fire: "193"
  },
  mexico: {
    police: "911",
    ambulance: "911",
    fire: "911"
  }
};

// destinationKey -> homeCountryKey -> embassy. See the header comment above
// for sourcing. Not every destination has every home country filled in —
// admins can always add more through the admin tool itself.
export const DEFAULT_EMBASSIES = {
  malaysia: {
    brunei: {
      missionName: "High Commission of Brunei Darussalam, Kuala Lumpur",
      address: "No. 2, Jalan Diplomatik 2/5, Precinct 15, 62050 Putrajaya, Malaysia",
      officeLines: [
        "+603 8888 7777",
        "+6019 212 0114 (hotline/WhatsApp)"
      ],
      email: "sjtkl@mfa.gov.bn"
    },
    singapore: {
      missionName: "High Commission of the Republic of Singapore, Kuala Lumpur",
      address: "209 Jalan Tun Razak, 50400 Kuala Lumpur, Malaysia",
      officeLines: [
        "+60 3-2161 6277"
      ]
    },
    indonesia: {
      missionName: "Embassy of the Republic of Indonesia, Kuala Lumpur",
      address: "233, Jalan Tun Razak, Kuala Lumpur 50400, Malaysia",
      officeLines: [
        "(603) 2116 4000"
      ],
      emergencyPhone: "+62-812-9007-0027",
      email: "pelindunganwni@kemlu.go.id"
    },
    thailand: {
      missionName: "Royal Thai Embassy, Kuala Lumpur",
      address: "206 Jalan Ampang, 50450 Kuala Lumpur, Malaysia",
      officeLines: [
        "+60 3-2145-8004",
        "+60 3-2148-8420",
        "+60 3-2148-8222"
      ],
      email: "thaiembassy.kul@mfa.go.th"
    },
    philippines: {
      missionName: "Embassy of the Republic of the Philippines, Kuala Lumpur",
      address: "No. 1 Changkat Kia Peng, 50450 Kuala Lumpur, Malaysia",
      officeLines: [
        "+60-3-2148-4233",
        "+60-3-2148-4654",
        "+60-3-2148-4682",
        "+60-3-2148-6528",
        "+60-3-2148-6538"
      ],
      emergencyPhone: "+6017-347-5487 (Duty Officer)"
    },
    vietnam: {
      missionName: "Embassy of the Socialist Republic of Vietnam in Malaysia",
      address: "No. 4, Persiaran Stonor, 50450 Kuala Lumpur, Malaysia",
      officeLines: [
        "+60 3-2148 4534",
        "+60 3-2148 4036"
      ],
      email: "vnemb.my@mofa.gov.vn"
    },
    china: {
      missionName: "Embassy of the People's Republic of China, Kuala Lumpur",
      address: "229 Jalan Ampang, 50450 Kuala Lumpur, Malaysia",
      officeLines: [
        "+60 3-2176 0888 (visa centre)",
        "+60 3-2164 5250 (consular documents)",
        "+60 3-2145 3936 (political office)",
        "+60 3-2141 6093 (cultural office)",
        "+60 3-4251 3555 (commercial office)"
      ],
      emergencyPhone: "+60 3-2163 6853 (consular protection)",
      email: "chinaemb_my@mfa.gov.cn"
    },
    japan: {
      missionName: "Embassy of Japan in Malaysia",
      address: "No. 11 Persiaran Stonor, Off Jalan Tun Razak, 50450 Kuala Lumpur, Malaysia",
      officeLines: [
        "03-2177 2600"
      ],
      email: "ryo@kl.mofa.go.jp"
    },
    "south korea": {
      missionName: "Embassy of the Republic of Korea in Malaysia",
      officeLines: [
        "+60 3-4266-8900",
        "+60-3-4251-2336",
        "+800-2100-0404 (Sabah & Sarawak toll-free)"
      ],
      email: "korem-my@mofa.go.kr"
    },
    india: {
      missionName: "High Commission of India, Kuala Lumpur, Malaysia",
      address: "Level 1, Wisma HRIH Lotus, 442, Jalan Pahang, Setapak, 53000 Kuala Lumpur",
      officeLines: [
        "+60 3 4024 0990",
        "+60 3 4025 3366",
        "+60 3 4025 3434"
      ],
      emergencyPhone: "+60 12 602 0360",
      email: "hc.kl@mea.gov.in"
    },
    "united kingdom": {
      missionName: "British High Commission, Kuala Lumpur",
      address: "Level 27, Menara Binjai, 2 Jalan Binjai, 50450 Kuala Lumpur, Malaysia",
      officeLines: [
        "+60 3 2170 2200"
      ],
      emergencyPhone: "+44 (0)20 7008 5000",
      email: "UKinMalaysia@fcdo.gov.uk"
    },
    "united states": {
      missionName: "U.S. Embassy Kuala Lumpur",
      address: "376 Jalan Tun Razak, 50400 Kuala Lumpur, Malaysia",
      officeLines: [
        "+60 3 2168-5000"
      ],
      emergencyPhone: "+60 3 2168-5000 (press 0 for duty officer)",
      email: "klacs@state.gov"
    },
    australia: {
      missionName: "Australian High Commission, Malaysia",
      address: "No. 6, Jalan Yap Kwan Seng, 50450 Kuala Lumpur, Malaysia",
      officeLines: [
        "+60 3 2146 5555"
      ],
      emergencyPhone: "+61 2 6261 3305"
    }
  },
  singapore: {
    malaysia: {
      missionName: "High Commission of Malaysia, Singapore",
      address: "301 Jervois Road, Singapore 249077",
      officeLines: [
        "+65 6235 0111",
        "+65 6887 6256"
      ],
      email: "mwsingapore@kln.gov.my"
    },
    brunei: {
      missionName: "High Commission of Brunei Darussalam, Singapore",
      address: "325 Tanglin Road, Singapore 247955",
      officeLines: [
        "+65 6733 9055",
        "+65 9673 0300 (hotline)"
      ],
      emergencyPhone: "+65 8134 2996",
      email: "singapore@mfa.gov.bn"
    },
    indonesia: {
      missionName: "Embassy of the Republic of Indonesia, Singapore",
      address: "No. 7 Chatsworth Road, Singapore 249761",
      officeLines: [
        "(65) 9295 3964"
      ],
      emergencyPhone: "+62-812-9007-0027",
      email: "pelindunganwni@kemlu.go.id"
    },
    thailand: {
      missionName: "Royal Thai Embassy, Singapore",
      address: "370 Orchard Road, Singapore 238870",
      officeLines: [
        "+65 6737 2644"
      ],
      email: "thaiembassy.sin@mfa.go.th"
    },
    philippines: {
      missionName: "Embassy of the Republic of the Philippines, Singapore",
      address: "20 Nassim Road, Singapore 258395",
      officeLines: [
        "+65-6737-3977",
        "+65-6506-0542",
        "+65-6506-0543",
        "+65-6506-0547",
        "+65-6924-7596",
        "+65-8766-0151",
        "+65-6506-0545"
      ]
    },
    vietnam: {
      missionName: "Embassy of the Socialist Republic of Vietnam in the Republic of Singapore",
      address: "10 Leedon Park, Singapore 267887",
      officeLines: [
        "+65 8725 9062",
        "+65 6468 9863",
        "+65 6462 5936"
      ],
      email: "vnemb.sg@mofa.gov.vn"
    },
    china: {
      missionName: "Embassy of the People's Republic of China in the Republic of Singapore",
      address: "150 Tanglin Road, Singapore 247969",
      officeLines: [
        "+65 6418 0463",
        "+65 6471 2117"
      ],
      email: "chinaemb_sg@mfa.gov.cn"
    },
    japan: {
      missionName: "Embassy of Japan in Singapore",
      address: "16 Nassim Road, Singapore 258390",
      officeLines: [
        "(+65) 6235-8855"
      ],
      email: "enquiry@sn.mofa.go.jp"
    },
    india: {
      missionName: "High Commission of India, Singapore",
      address: "31 Grange Road, Singapore 239702",
      officeLines: [
        "+65 6737 6777"
      ],
      emergencyPhone: "+65 6238 2538",
      email: "hc.singapore@mea.gov.in"
    },
    "united kingdom": {
      missionName: "British High Commission Singapore",
      address: "100 Tanglin Road, Singapore 247919",
      officeLines: [
        "+65 6424 4200"
      ],
      emergencyPhone: "+44 (0)20 7008 5000"
    },
    "united states": {
      missionName: "U.S. Embassy Singapore",
      address: "27 Napier Road, Singapore 258508",
      officeLines: [
        "+65 6476-9100"
      ],
      emergencyPhone: "+65 6476-9100",
      email: "singaporeacs@state.gov"
    },
    australia: {
      missionName: "Australian High Commission, Singapore",
      address: "25 Napier Road, Singapore 258507",
      officeLines: [
        "+65 6836 4100"
      ],
      email: "enquiries.singapore@dfat.gov.au"
    },
    "south korea": {
      missionName: "Embassy of the Republic of Korea to the Republic of Singapore",
      address: "47 Scotts Road #08-00 Goldbell Towers, Singapore 228233",
      officeLines: [
        "65-6256-1188"
      ],
      emergencyPhone: "65-9654-3528",
      email: "korembsg@mofa.go.kr"
    }
  },
  indonesia: {
    malaysia: {
      missionName: "Embassy of Malaysia, Jakarta",
      address: "Jl. H.R. Rasuna Said Kav. X/6, No. 1-3, Kuningan, Jakarta Selatan 12950, Indonesia",
      officeLines: [
        "+62 21 522 4947"
      ],
      emergencyPhone: "+62 813 8081 3036",
      email: "mwjakarta@kln.gov.my"
    },
    brunei: {
      missionName: "Embassy of Brunei Darussalam, Jakarta",
      address: "Menara Sunlife, Lantai 22, Jl. Dr. Ide Anak Agung Gde Agung, Mega Kuningan, Jakarta Selatan, Indonesia",
      officeLines: [
        "+62 21 2123 7807",
        "+62 21 2123 7808",
        "+62 811 9006 564 (hotline)"
      ],
      email: "jakarta.indonesia@mfa.gov.bn"
    },
    singapore: {
      missionName: "Embassy of the Republic of Singapore, Jakarta",
      address: "Jalan H.R. Rasuna Said, Block X/4, Kav. No. 2, Kuningan, Jakarta Selatan 12950, Indonesia",
      officeLines: [
        "+62 21 5091 5400",
        "+62 21 520 1469"
      ],
      emergencyPhone: "+62 21 5091 5400 (after office hours)",
      email: "singemb_jkt@mfa.sg"
    },
    thailand: {
      missionName: "Royal Thai Embassy, Jakarta",
      address: "Jl. Dr. Ide Anak Agung Gde Agung Kav. 3.3 (Lot 8.8), Kawasan Mega Kuningan, Jakarta 12950, Indonesia",
      officeLines: [
        "+62 21 2932 8190",
        "+62 21 2932 8194"
      ],
      email: "thaijkt@thaiembassy.co.id"
    },
    philippines: {
      missionName: "Embassy of the Republic of the Philippines, Jakarta",
      address: "Jalan Imam Bonjol No. 8, Menteng, Jakarta Pusat 10310, Indonesia",
      officeLines: [
        "+62-21-310-0334"
      ],
      emergencyPhone: "+62-811-887-344 (Assistance to Nationals, WhatsApp, after office hours)"
    },
    vietnam: {
      missionName: "Embassy of the Socialist Republic of Vietnam in Indonesia",
      address: "Jl. Teuku Umar No. 25, Central Jakarta, Indonesia",
      officeLines: [
        "+62 21-3100358",
        "+62 21-3149615"
      ],
      email: "jakarta@mofa.gov.vn"
    },
    china: {
      missionName: "Embassy of the People's Republic of China in the Republic of Indonesia",
      address: "Jl. Mega Kuningan No. 2, Jakarta Selatan 12950, Indonesia",
      officeLines: [
        "+62 21 5761039"
      ],
      emergencyPhone: "+62 21 5764135",
      email: "chinaemb_id@mfa.gov.cn"
    },
    japan: {
      missionName: "Embassy of Japan in Indonesia",
      address: "Jl. M.H. Thamrin No.24, Jakarta 10350, Indonesia",
      officeLines: [
        "(62-21) 324308"
      ]
    },
    "united kingdom": {
      missionName: "British Embassy Jakarta",
      address: "Jl Patra Kuningan Raya Blok L5-6, Jakarta 12950, Indonesia",
      officeLines: [
        "+62 21 2356 5200"
      ]
    },
    "united states": {
      missionName: "U.S. Embassy Jakarta",
      address: "Jl. Medan Merdeka Selatan No. 3-5, Jakarta 10110, Indonesia",
      officeLines: [
        "+62 21 3435-9000"
      ],
      emergencyPhone: "+62 21 3435-9000 ext. 0 (operator)",
      email: "JakartaACS@state.gov"
    },
    australia: {
      missionName: "Australian Embassy, Indonesia",
      address: "Jalan Patra Kuningan Raya Kav. 1-4, Jakarta Selatan 12950, Indonesia",
      officeLines: [
        "+62 21 2550 5555"
      ],
      emergencyPhone: "+61 2 6261 3305",
      email: "public-affairs-jakt@dfat.gov.au"
    }
  },
  thailand: {
    malaysia: {
      missionName: "Embassy of Malaysia, Bangkok",
      address: "33-35 South Sathorn Road, Tungmahamek, Sathorn, 10120 Bangkok, Thailand",
      officeLines: [
        "+66-2340-5720",
        "+66-2340-5731"
      ],
      emergencyPhone: "+66-87-028-4659",
      email: "mwbangkok@kln.gov.my"
    },
    brunei: {
      missionName: "Embassy of Brunei Darussalam, Bangkok",
      address: "No. 12, Soi Ekamai 2 (Soi 63), Sukhumvit Road, Khlong Tan Nua, Wattana, Bangkok 10110, Thailand",
      officeLines: [
        "+66 2 714 7395",
        "+66 2 714 7396",
        "+66 2 714 7397",
        "+66 2 714 7398",
        "+66 2 714 7399",
        "+66 92 270 9382 (hotline)"
      ],
      email: "bangkok.thailand@mfa.gov.bn"
    },
    singapore: {
      missionName: "Embassy of the Republic of Singapore, Bangkok",
      officeLines: [
        "+66 2 348 6700"
      ],
      emergencyPhone: "+66 2 348 6700 ext. 348 (consular emergencies)",
      email: "singemb_bkk@mfa.sg"
    },
    indonesia: {
      missionName: "Embassy of the Republic of Indonesia, Bangkok",
      address: "600-602 Petchburi Road, Ratchatewi, Bangkok 10400, Thailand",
      officeLines: [
        "(66-2) 252 3135-40"
      ],
      emergencyPhone: "+62-812-9007-0027",
      email: "pelindunganwni@kemlu.go.id"
    },
    philippines: {
      missionName: "Embassy of the Republic of the Philippines, Bangkok",
      address: "760 Sukhumvit Road corner Soi Philippines (Soi 30/1), Bangkok 10110, Thailand",
      officeLines: [
        "+66-2-259-0139",
        "+66-2-259-0140",
        "+66-2-258-5401"
      ],
      emergencyPhone: "+66-89-926-5954 (Duty Officer Hotline); +66-81-989-7116 (Assistance to Nationals, after hours)",
      email: "bangkokpe.consular@dfa.gov.ph"
    },
    vietnam: {
      missionName: "Embassy of the Socialist Republic of Vietnam in Thailand",
      address: "83/1 Wireless Road, Lumpini, Pathumwan, Bangkok, Thailand",
      officeLines: [
        "+66 2 650 8979",
        "+66 2 251 5838",
        "+66 2 253 4464"
      ],
      emergencyPhone: "+66 89 896 6653",
      email: "vnemb.th@mofa.gov.vn"
    },
    japan: {
      missionName: "Embassy of Japan in Thailand",
      address: "177 Witthayu Road, Lumphini, Pathum Wan, Bangkok 10330, Thailand",
      officeLines: [
        "02-207-8500",
        "02-696-3000"
      ],
      email: "jis@bg.mofa.go.jp"
    },
    india: {
      missionName: "Embassy of India, Bangkok, Thailand",
      address: "46 Prasarnmitr, Sukhumvit Soi 23, Bangkok 10110",
      officeLines: [
        "02-2580300-6",
        "02-2580307",
        "02-2604166"
      ],
      emergencyPhone: "+66-618819218",
      email: "cons.bangkok@mea.gov.in"
    },
    "united kingdom": {
      missionName: "British Embassy Bangkok",
      address: "AIA Sathorn Tower, Floor 12A, 11/1 South Sathorn Road, Sathorn, Bangkok 10120, Thailand",
      officeLines: [
        "+66 (0)2 305 8333"
      ],
      emergencyPhone: "+44 (0)20 7008 5000",
      email: "Info.Bangkok@fcdo.gov.uk"
    },
    "united states": {
      missionName: "U.S. Embassy Bangkok",
      address: "95 Wireless Road, Bangkok 10330, Thailand",
      officeLines: [
        "+66 2 205-4049"
      ],
      emergencyPhone: "+66 2 205-4000",
      email: "acsbkk@state.gov"
    },
    china: {
      missionName: "Consulate General of the People's Republic of China in Songkhla, Thailand",
      address: "9 Sadao Road/Alley, Tambon Bo Yang, Amphur Muang, Songkhla 90000, Thailand",
      officeLines: [
        "0066-74-322034",
        "0066-74-300798"
      ],
      emergencyPhone: "0066-81-7665560",
      email: "chinaconsul_skh_th@mfa.gov.cn",
      _source: "https://www.mfa.gov.cn/esp/wjb/zwjg/zwzlg/yz/200709/t20070920_927843.html and https://songkhla.china-consulate.gov.cn/eng/zlshd/202603/t20260319_11877382.htm (both official China MFA / consulate domains)",
      _note: "IMPORTANT: this is the Consulate General in Songkhla (southern Thailand), not the main Embassy in Bangkok. Repeated attempts (30+) to retrieve the Bangkok Embassy's own official contact page from mfa.gov.cn (the correct directory pages consistently returned server errors) and china-embassy.gov.cn (blocked by robots.txt for fetching) were unsuccessful. Treat this as a verified but partial/substitute entry — recommend further attempt in a future run to get the Bangkok Embassy specifically, or use this Songkhla consulate data with a 'Consulate (South Thailand)' label rather than presenting it as the Bangkok Embassy."
    },
    australia: {
      missionName: "Australian Embassy, Thailand",
      address: "181 Wireless Road, Lumphini, Pathumwan, Bangkok 10330, Thailand",
      officeLines: [
        "+66 2 344 6300"
      ],
      emergencyPhone: "+61 2 6261 3305"
    },
    "south korea": {
      missionName: "Embassy of the Republic of Korea in Thailand",
      address: "23 Thiam-Ruammit Rd, Ratchadapisek, Huay-Kwang, Bangkok, 10320, Thailand",
      officeLines: [
        "02-247-7537 to 02-247-7539"
      ],
      email: "koembth@mofa.go.kr"
    }
  },
  vietnam: {
    malaysia: {
      missionName: "Consulate General of Malaysia, Ho Chi Minh City",
      address: "109 Nguyen Van Huong, Thao Dien Ward, District 2, Ho Chi Minh City, Vietnam",
      officeLines: [
        "+84 (0)28-3829 9023"
      ],
      emergencyPhone: "+84 (0)76 564 9660",
      email: "mwhochiminh@kln.gov.my"
    },
    brunei: {
      missionName: "Embassy of Brunei Darussalam, Hanoi",
      address: "298C Kim Ma Street, Ba Dinh District, Hanoi, Vietnam",
      officeLines: [
        "+84 24 3726 2001",
        "+84 24 3726 2002",
        "+84 90 222 4661 (hotline)"
      ],
      email: "hanoi.vietnam@mfa.gov.bn"
    },
    singapore: {
      missionName: "Embassy of the Republic of Singapore, Hanoi",
      address: "41-43 Tran Phu Street, Hanoi, Vietnam",
      officeLines: [
        "+84 24 3848 9170-77"
      ],
      emergencyPhone: "+84 904 696 589 (Singaporeans only, after office hours)",
      email: "singemb_han@mfa.sg"
    },
    indonesia: {
      missionName: "Embassy of the Republic of Indonesia, Hanoi",
      address: "50 Ngo Quyen Street, Hanoi, Vietnam",
      officeLines: [
        "(+84-4) 3825-3353",
        "(+84-4) 3825-3324",
        "(+84-4) 3925-796",
        "(+84-4) 3825-6316"
      ],
      emergencyPhone: "+62-812-9007-0027",
      email: "pelindunganwni@kemlu.go.id"
    },
    thailand: {
      missionName: "Royal Thai Embassy, Hanoi",
      address: "26 Phan Boi Chau Street, Hoan Kiem District, Hanoi, Vietnam",
      officeLines: [
        "+84 24 3823 5092",
        "+84 24 3823 5094"
      ],
      email: "thaiembassy.han@mfa.go.th"
    },
    philippines: {
      missionName: "Embassy of the Philippines, Hanoi",
      address: "27B Tran Hung Dao Street, Hanoi, Vietnam",
      officeLines: [
        "+84-24-3943-7873"
      ],
      emergencyPhone: "+84-904-126-164 (weekends, holidays, outside office hours)"
    },
    japan: {
      missionName: "Embassy of Japan in Viet Nam",
      address: "27 Lieu Giai, Ngoc Ha District, Hanoi, Viet Nam",
      officeLines: [
        "84-(0)24-3846-3000"
      ]
    },
    india: {
      missionName: "Embassy of India, Hanoi, Vietnam",
      emergencyPhone: "+84-913089165",
      email: "cons.hanoi@mea.gov.in"
    },
    "united kingdom": {
      missionName: "British Embassy Hanoi",
      address: "Central Building, 4th Floor, 31 Hai Ba Trung, Cua Nam Ward, Hanoi, Vietnam",
      officeLines: [
        "+84 24 3936 0500"
      ],
      emergencyPhone: "+44 (0)20 7008 5000"
    },
    "united states": {
      missionName: "U.S. Embassy Hanoi",
      address: "170 Ngoc Khanh, Ba Dinh District, Hanoi, Vietnam",
      officeLines: [
        "+84 24 3850-5000"
      ],
      emergencyPhone: "+84 24 3850-5000",
      email: "acshanoi@state.gov"
    },
    australia: {
      missionName: "Australian Embassy, Vietnam",
      address: "8 Dao Tan Street, Giang Vo Ward, Hanoi, Vietnam",
      officeLines: [
        "+84 24 3774 0100"
      ],
      emergencyPhone: "+61 2 6261 3305"
    }
  },
  philippines: {
    malaysia: {
      missionName: "Embassy of Malaysia, Manila",
      address: "107 Tordesillas Street, Salcedo Village, Makati, Metro Manila, Philippines",
      officeLines: [
        "+63 2 8662 8200"
      ],
      emergencyPhone: "+63 961 077 8113",
      email: "MalaysianEmbassyPh@gmail.com"
    },
    brunei: {
      missionName: "Embassy of Brunei Darussalam, Manila",
      address: "22nd Floor, Century Diamond Tower, Kalayaan Avenue corner Salamanca Street, Makati City 1200, Philippines",
      officeLines: [
        "+63 2 8816 2836",
        "+63 927 735 3401 (hotline)"
      ],
      email: "manila.philippines@mfa.gov.bn"
    },
    singapore: {
      missionName: "Embassy of the Republic of Singapore, Manila",
      address: "505 Rizal Drive, Bonifacio Global City, 1634 Taguig City, Metro Manila, Philippines",
      officeLines: [
        "+63 2 8856 9922"
      ],
      email: "singemb_mnl@mfa.sg"
    },
    indonesia: {
      missionName: "Embassy of the Republic of Indonesia, Manila",
      address: "185 Salcedo Street, Legaspi Village, Makati City, Metro Manila 1229, Philippines",
      officeLines: [
        "+63 2 892 5062-68"
      ],
      emergencyPhone: "+62-812-9007-0027",
      email: "pelindunganwni@kemlu.go.id"
    },
    thailand: {
      missionName: "Royal Thai Embassy, Manila",
      address: "107 Rada Street, Legaspi Village, Makati City, Metro Manila, Philippines",
      officeLines: [
        "+63 2 8810-3833"
      ],
      email: "thaiembassy.mnl@mfa.go.th"
    },
    vietnam: {
      missionName: "Embassy of the Socialist Republic of Vietnam in the Philippines",
      address: "670 Pablo Ocampo Sr. Street, Malate, Manila, Philippines",
      officeLines: [
        "+63 2 8521 6843"
      ],
      email: "vnembph@mofa.gov.vn"
    },
    china: {
      missionName: "Embassy of the People's Republic of China, Manila",
      address: "4896 Pasay Road, Dasmarinas Village, Makati, Metro Manila, Republic of the Philippines",
      officeLines: [
        "+63 2 844 3148 (switchboard)",
        "+63 2 819 5991 (commercial office)",
        "+63 2 848 2395 (visa & documents section)",
        "+63 2 867 1762 (cultural office)"
      ],
      emergencyPhone: "+63 2 848 2409 (consular protection); duty officer +63 2 8231 1033",
      email: "chinaemb_ph@mfa.gov.cn"
    },
    japan: {
      missionName: "Embassy of Japan in the Philippines",
      address: "2627 Roxas Boulevard, Pasay City, Metro Manila 1300, Philippines",
      officeLines: [
        "(63-2) 8551-5710"
      ]
    },
    india: {
      missionName: "Embassy of India, Manila, Philippines",
      address: "2190 Paraiso St., Dasmariñas Village, Makati, Metro Manila (Chancery); Consular/Visa Wing: Unit 2702, 27th Floor, One World Place, 32nd Street, Bonifacio Global City, Taguig City 1634",
      officeLines: [
        "(02) 8843-0101",
        "(02) 8843-0102",
        "(02) 8784-6342",
        "(02) 8563-4592",
        "(02) 8563-4584"
      ],
      emergencyPhone: "+63 917 108 6301",
      email: "cons.manila@mea.gov.in"
    },
    "united kingdom": {
      missionName: "British Embassy Manila",
      address: "120 Upper McKinley Road, McKinley Hill, Taguig City, Metro Manila 1634, Philippines",
      officeLines: [
        "+63 2 8858 2200"
      ],
      emergencyPhone: "+44 (0)20 7008 1500"
    },
    "united states": {
      missionName: "U.S. Embassy Manila",
      address: "1201 Roxas Boulevard, Manila, Philippines 1000",
      officeLines: [
        "+63 2 301-2000"
      ],
      emergencyPhone: "+63 2 301-2000 x0",
      email: "acsinfomanila@state.gov"
    },
    australia: {
      missionName: "Australian Embassy, Philippines",
      address: "Level 23, Tower 2, RCBC Plaza, 6819 Ayala Avenue, Makati City 1200, Philippines",
      officeLines: [
        "+63 2 7757 8100"
      ],
      emergencyPhone: "+61 2 6261 3305",
      email: "australianembassy.manila@dfat.gov.au"
    },
    "south korea": {
      missionName: "Embassy of the Republic of Korea in the Philippines",
      address: "122 Upper McKinley Road, McKinley Town Center, Fort Bonifacio, Taguig City 1634, Philippines",
      officeLines: [
        "+63-2-8856-9210"
      ],
      emergencyPhone: "+63-917-817-5703",
      email: "ph04@mofa.go.kr"
    }
  },
  japan: {
    malaysia: {
      missionName: "Embassy of Malaysia, Tokyo",
      address: "20-16, Nanpeidai-cho, Shibuya-ku, Tokyo 150-0036, Japan",
      officeLines: [
        "+81-3-3476-3840"
      ],
      emergencyPhone: "+81-80-4322-3366",
      email: "mwtokyo@kln.gov.my"
    },
    brunei: {
      missionName: "Embassy of Brunei Darussalam, Tokyo",
      address: "6-5-2 Kita-Shinagawa, Shinagawa-ku, Tokyo 141-0001, Japan",
      officeLines: [
        "+81 3 3447 7997",
        "+81 80 1161 5328 (hotline)"
      ],
      email: "tokyo.japan@mfa.gov.bn"
    },
    singapore: {
      missionName: "Embassy of the Republic of Singapore, Tokyo",
      address: "5-12-3 Roppongi, Minato-ku, Tokyo 106-0032, Japan",
      officeLines: [
        "+81 3 3586 9111"
      ],
      emergencyPhone: "+81 90 5949 6366 / +81 90 5258 3252 (24-hour emergency consular)",
      email: "singemb_tyo@mfa.sg"
    },
    indonesia: {
      missionName: "Embassy of the Republic of Indonesia, Tokyo",
      address: "5-2-9 Higashigotanda, Shinagawa-ku, Tokyo, Japan",
      officeLines: [
        "+81-03-3441-4201"
      ],
      emergencyPhone: "+62-812-9007-0027",
      email: "pelindunganwni@kemlu.go.id"
    },
    thailand: {
      missionName: "Royal Thai Embassy, Tokyo",
      address: "3-14-6 Kami-Osaki, Shinagawa-ku, Tokyo 141-0021, Japan",
      officeLines: [
        "+81 3 5789 2433"
      ]
    },
    philippines: {
      missionName: "Embassy of the Philippines, Tokyo",
      address: "5-15-5 Roppongi, Minato-ku, Tokyo 106-8537, Japan",
      officeLines: [
        "+81-3-5562-1600"
      ],
      emergencyPhone: "+81-80-4928-7979 (outside office hours, weekends, holidays)"
    },
    vietnam: {
      missionName: "Embassy of the Socialist Republic of Vietnam in Japan",
      address: "50-11 Motoyoyogi-cho, Shibuya-ku, Tokyo 151-0062, Japan",
      officeLines: [
        "+81 3-3466-3311",
        "+81 3-3466-3313",
        "+81 3-3466-3314",
        "+81 3-3466-3312"
      ],
      emergencyPhone: "+81 80-3590-9136",
      email: "vietnamembassy-japan@vnembassy.jp"
    },
    india: {
      missionName: "Embassy of India, Tokyo, Japan",
      address: "2-2-11 Kudan-Minami, Chiyoda-ku, Tokyo 102-0074",
      officeLines: [
        "+81 3 3262-2397",
        "81-3 3262-2391 to 97"
      ],
      email: "amboffice.tokyo@mea.gov.in"
    },
    "united kingdom": {
      missionName: "British Embassy Tokyo",
      address: "1 Ichiban-cho, Chiyoda-ku, Tokyo 102-8381, Japan",
      officeLines: [
        "+81 (0)3 5211 1100"
      ],
      emergencyPhone: "+44 (0)20 7008 1500"
    },
    "united states": {
      missionName: "U.S. Embassy Tokyo",
      address: "1-10-5 Akasaka, Minato-ku, Tokyo 107-8420, Japan",
      officeLines: [
        "+81 3-3224-5000"
      ],
      emergencyPhone: "+81 3-3224-5000",
      email: "Tokyoacs@state.gov"
    },
    australia: {
      missionName: "Australian Embassy, Japan",
      address: "2-1-14 Mita, Minato-ku, Tokyo 108-8361, Japan",
      officeLines: [
        "+81 3 5232 4111"
      ],
      emergencyPhone: "+61 2 6261 3305"
    }
  },
  "south korea": {
    malaysia: {
      missionName: "Embassy of Malaysia, Seoul",
      address: "129 Dokseodang-ro, Hannam-dong, Yongsan-gu, Seoul, Republic of Korea",
      officeLines: [
        "+82-2-2077 8600"
      ],
      emergencyPhone: "+82 10 8974 8699",
      email: "mwseoul@kln.gov.my"
    },
    brunei: {
      missionName: "Embassy of Brunei Darussalam, Seoul",
      address: "133 Jahamun-ro, Jongno-gu, Seoul 03031, Republic of Korea",
      officeLines: [
        "+82 2 790 1078",
        "+82 2 790 1079",
        "+82 10 4406 3808 (hotline)"
      ],
      email: "seoul.korea@mfa.gov.bn"
    },
    singapore: {
      missionName: "Embassy of the Republic of Singapore, Seoul",
      officeLines: [
        "+82 2 774 2464",
        "+82 2 774 2465"
      ],
      emergencyPhone: "+82 10 7204 6240 (Duty Officer, urgent consular assistance after office hours)",
      email: "singemb_seo@mfa.sg"
    },
    indonesia: {
      missionName: "Embassy of the Republic of Indonesia, Seoul",
      address: "380 Yuidaebang-ro, Yeongdeungpo-gu, Seoul 150-895, Republic of Korea",
      officeLines: [
        "+82-02-783-5676/7"
      ],
      emergencyPhone: "+62-812-9007-0027",
      email: "pelindunganwni@kemlu.go.id"
    },
    thailand: {
      missionName: "Royal Thai Embassy, Seoul",
      address: "42 Daesagwan-ro, Hannam-dong, Yongsan-gu, Seoul, South Korea",
      officeLines: [
        "02-795-3253",
        "02-795-1593",
        "02-795-1594",
        "02-795-0981"
      ],
      email: "thaiembassy.SEL@mfa.go.th"
    },
    philippines: {
      missionName: "Embassy of the Republic of the Philippines, Seoul",
      address: "80 Hoenamu-ro, Yongsan-gu, Seoul, Republic of Korea",
      officeLines: [
        "+82-2-788-2100",
        "+82-2-788-2101"
      ],
      email: "consular@philembassy-seoul.com"
    },
    vietnam: {
      missionName: "Embassy of the Socialist Republic of Vietnam in the Republic of Korea",
      address: "123 Bukchon-ro, Jongno-gu, Seoul 03052, South Korea",
      officeLines: [
        "+82 2-720-5124",
        "+82 2-720-4684"
      ],
      email: "vietnamembassyseoul@gmail.com"
    },
    china: {
      missionName: "Embassy of the People's Republic of China in the Republic of Korea",
      address: "54 Hyoja-dong, Jongno-gu, Seoul 110-033, Republic of Korea",
      officeLines: [
        "+82 2 738 1038"
      ],
      email: "chinaemb_kr@mfa.gov.cn"
    },
    japan: {
      missionName: "Embassy of Japan in the Republic of Korea",
      address: "Twin Tree Tower A, 6, Yulgok-ro, Jongno-gu, Seoul, Republic of Korea",
      officeLines: [
        "(82-2) 2170-5200",
        "(82-2) 739-7400"
      ]
    },
    india: {
      missionName: "Embassy of India, Seoul, Republic of Korea",
      address: "101, Hannam Dong, Dokseodang-ro, Yongsan-gu, Seoul 04419, Republic of Korea",
      officeLines: [
        "+82-2-798-4257",
        "+82-2-798-4268",
        "+82-2-798-4244",
        "+82-2-798-0962",
        "+82-2-798-2653"
      ],
      emergencyPhone: "010-9356-4188",
      email: "cons.seoul@mea.gov.in"
    },
    "united kingdom": {
      missionName: "British Embassy Seoul",
      address: "Sejong-daero 19-gil 24, Jung-gu, Seoul 04519, South Korea",
      officeLines: [
        "+82 (0)2 3210 5500"
      ]
    },
    "united states": {
      missionName: "U.S. Embassy Seoul",
      address: "188 Sejong-daero, Jongno-gu, Seoul, Republic of Korea 110-710",
      officeLines: [
        "+82 2 397-4114"
      ],
      emergencyPhone: "+82 2 397-4114",
      email: "seoulinfoACS@state.gov"
    },
    australia: {
      missionName: "Australian Embassy, Republic of Korea",
      address: "19th Floor, Kyobo Building, 1 Jongro, Jongno-Gu, Seoul 03154, Republic of Korea",
      officeLines: [
        "+82 2 2003 0100"
      ]
    }
  },
  china: {
    malaysia: {
      missionName: "Embassy of Malaysia, Beijing",
      address: "No. 2, Liang Ma Qiao Bei Jie, Chaoyang District, Beijing, People's Republic of China",
      officeLines: [
        "+86-10-6532-2531"
      ],
      emergencyPhone: "+86 137 1894 2581",
      email: "mwbeijing@kln.gov.my"
    },
    brunei: {
      missionName: "Embassy of Brunei Darussalam, Beijing",
      address: "No. 1 Liangmaqiao Beijie, Chaoyang District, Beijing 100600, People's Republic of China",
      officeLines: [
        "+86 10 6532 9773",
        "+86 10 6532 9776",
        "+86 156 5275 1992 (hotline)"
      ],
      email: "beijing.china@mfa.gov.bn"
    },
    singapore: {
      missionName: "Embassy of the Republic of Singapore, Beijing",
      address: "No. 1 Xiushui Beijie, Jianguomenwai, Beijing 100600, China",
      officeLines: [
        "+86 10 6532 9380"
      ],
      emergencyPhone: "+86 139 1075 5251 (Beijing Duty Officer, urgent consular matters only)",
      email: "singemb_bej@mfa.sg"
    },
    indonesia: {
      missionName: "Embassy of the Republic of Indonesia, Beijing",
      address: "Dongzhimen Wai Da Jie No. 4, Chaoyang District, Beijing 100600, P.R. China",
      officeLines: [
        "(86-10) 6532 5486",
        "(86-10) 6532 5488"
      ],
      emergencyPhone: "+62-812-9007-0027",
      email: "pelindunganwni@kemlu.go.id"
    },
    thailand: {
      missionName: "Royal Thai Embassy, Beijing",
      address: "21 Guanghua Road, Chaoyang District, Beijing 100600, China",
      officeLines: [
        "+86 10 8531-8700",
        "+86 10 8531-8769"
      ],
      email: "visa.pek@mfa.go.th"
    },
    philippines: {
      missionName: "Embassy of the Republic of the Philippines, Beijing",
      address: "23 Xiu Shui Bei Jie, Jianguomenwai, Beijing 100600, People's Republic of China",
      officeLines: [
        "+86-10-6532-2451",
        "+86-10-6532-1872",
        "+86-10-6532-2518"
      ],
      emergencyPhone: "+86-138-1112-0334 (Duty Officer); +86-139-1118-0495 (Assistance-to-Nationals Hotline)"
    },
    vietnam: {
      missionName: "Embassy of the Socialist Republic of Vietnam in China",
      address: "No. 32 Guanghua Road, Chaoyang District, Beijing 100600, China",
      officeLines: [
        "+86 10-6532-1155"
      ],
      email: "dsqbk1@yahoo.com"
    },
    japan: {
      missionName: "Embassy of Japan in China",
      address: "No.1 Liangmaqiao Dongjie, Chaoyang District, Beijing 100600, China",
      officeLines: [
        "(86-10) 8531-9800"
      ]
    },
    india: {
      missionName: "Embassy of India, Beijing, China",
      officeLines: [
        "+86-10-8531 2500",
        "+86-10-8531 2501",
        "+86-10-8531 2502",
        "+86-10-8531 2503"
      ],
      emergencyPhone: "0086-185-1428-4905"
    },
    "united kingdom": {
      missionName: "British Embassy Beijing",
      address: "11 Guang Hua Lu, Jian Guo Men Wai, Beijing 100600, China",
      officeLines: [
        "+86 (0)10 5192 4000"
      ],
      emergencyPhone: "+44 (0)20 7008 5000",
      email: "beijing.consularsection@fcdo.gov.uk"
    },
    "united states": {
      missionName: "U.S. Embassy Beijing",
      address: "No. 55 An Jia Lou Road, Chaoyang District, Beijing 100600, China",
      officeLines: [
        "+86 10 8531-4000"
      ],
      emergencyPhone: "+86 10 8531-4000",
      email: "BeijingACS@state.gov"
    },
    australia: {
      missionName: "Australian Embassy, China",
      address: "21 Dongzhimenwai Street, Chaoyang District, Beijing 100600, People's Republic of China",
      officeLines: [
        "+86 10 5140 4111"
      ],
      emergencyPhone: "+61 2 6261 3305"
    }
  },
  "hong kong": {
    malaysia: {
      missionName: "Consulate General of Malaysia, Hong Kong",
      address: "24th Floor, Malaysia Building, 47-50 Gloucester Road, Wanchai, Hong Kong",
      officeLines: [
        "+852 2821 0800"
      ],
      emergencyPhone: "+852 6900 6390",
      email: "mwhongkong@kln.gov.my"
    },
    brunei: {
      missionName: "Consulate General of Brunei Darussalam, Hong Kong",
      address: "Room 05-07, 24th Floor, Tower Two, Lippo Centre, 89 Queensway, Hong Kong",
      officeLines: [
        "+852 2592 3900",
        "+852 2592 3917",
        "+852 2592 3918",
        "+852 6621 3385 (hotline)"
      ],
      email: "hongkong.china@mfa.gov.bn"
    },
    singapore: {
      missionName: "Consulate-General of the Republic of Singapore, Hong Kong",
      address: "Units 901-902, 9/F, Admiralty Centre Tower 1, 18 Harcourt Road, Admiralty, Hong Kong",
      officeLines: [
        "+852 2527 2212"
      ],
      emergencyPhone: "+852 9466 1251 (Duty Officer, urgent consular assistance only)",
      email: "singcg_hkg@mfa.sg"
    },
    indonesia: {
      missionName: "Consulate General of the Republic of Indonesia, Hong Kong",
      address: "127-129 Leighton Road, 6-8 Keswick Street, Causeway Bay, Hong Kong, P.R. China",
      officeLines: [
        "(852) 3651 0200"
      ],
      emergencyPhone: "+62-812-9007-0027",
      email: "pelindunganwni@kemlu.go.id"
    },
    thailand: {
      missionName: "Royal Thai Consulate-General, Hong Kong",
      address: "8/F, Fairmont House, 8 Cotton Tree Drive, Central, Hong Kong",
      officeLines: [
        "+852 2521 6481",
        "+852 2521 8629"
      ]
    },
    philippines: {
      missionName: "Philippine Consulate General, Hong Kong",
      address: "14th Floor, United Centre, 95 Queensway, Admiralty, Hong Kong",
      officeLines: [
        "+852-2823-8500"
      ],
      emergencyPhone: "+852-9155-4023 (PCG Hotline, after office hours/weekends/holidays)"
    },
    vietnam: {
      missionName: "Consulate-General of the Socialist Republic of Vietnam in Hong Kong",
      address: "15/F, Great Smart Tower, 230 Wan Chai Road, Wan Chai, Hong Kong",
      officeLines: [
        "+852 2591 4510",
        "+852 2591 4517",
        "+852 2835 9358",
        "+852 2835 9398"
      ],
      emergencyPhone: "+852 5378 8488",
      email: "vnconsul.hongkong@mofa.gov.vn"
    },
    japan: {
      missionName: "Consulate-General of Japan in Hong Kong",
      address: "46th & 47th Floors, One Exchange Square, 8 Connaught Place, Central, Hong Kong",
      officeLines: [
        "(852) 2522-1184"
      ]
    },
    india: {
      missionName: "Consulate General of India, Hong Kong",
      address: "Unit A/D, 16th Floor, United Centre, 95 Queensway, Admiralty, Hong Kong",
      officeLines: [
        "(852) 3970 9900",
        "(852) 3970 9911",
        "(852) 3970 9960",
        "(852) 3970 9940",
        "(852) 3970 9924",
        "(852) 3970 9922"
      ],
      emergencyPhone: "(852) 9077 1083",
      email: "cg.hongkong@mea.gov.in"
    },
    "united kingdom": {
      missionName: "British Consulate-General Hong Kong",
      address: "1 Supreme Court Road, Admiralty, Hong Kong",
      officeLines: [
        "+852 2901 3000"
      ]
    },
    "united states": {
      missionName: "U.S. Consulate General Hong Kong & Macau",
      address: "26 Garden Road, Central, Hong Kong",
      officeLines: [
        "+852 2841-2211",
        "+852 2841-2225",
        "+852 2841-2323"
      ],
      emergencyPhone: "+852 2523-9011",
      email: "acshk@state.gov"
    },
    australia: {
      missionName: "Australian Consulate-General, Hong Kong",
      address: "23/F, Harbour Centre, 25 Harbour Road, Wan Chai, Hong Kong SAR",
      officeLines: [
        "+852 2827 8881"
      ],
      email: "consular.hongkong@dfat.gov.au"
    },
    "south korea": {
      missionName: "Consulate General of the Republic of Korea in Hong Kong",
      address: "5/F, Far East Finance Centre, 16 Harcourt Road, Hong Kong",
      officeLines: [
        "(+852) 2529-4141"
      ],
      email: "hkg-info@mofa.go.kr"
    }
  },
  taiwan: {
    malaysia: {
      missionName: "Malaysian Friendship and Trade Centre, Taipei",
      address: "8th Floor, San Ho Plastic Building, No. 102 Dunhua N. Road, Songshan District, Taipei City, Taiwan",
      officeLines: [
        "+886-2-2713 2626"
      ],
      email: "mwtaipei@kln.gov.my"
    },
    singapore: {
      missionName: "Singapore Trade Office in Taipei",
      officeLines: [
        "+886 2 2772 1940"
      ],
      emergencyPhone: "+886 953 532 638 (urgent after-hours duty hotline)",
      email: "singtr_tpe@mfa.sg"
    },
    thailand: {
      missionName: "Thailand Trade and Economic Office, Taipei",
      address: "No. 206, Civic Boulevard Section 3, Taipei City 10666, Taiwan",
      officeLines: [
        "+886 2 2773 1100"
      ],
      email: "thaiteo.tpe@mfa.go.th"
    },
    vietnam: {
      missionName: "Vietnam Economic and Cultural Office in Taipei",
      address: "3F, No. 65 Sung Chiang Road, Taipei, Taiwan",
      officeLines: [
        "+886 2-2508-1869",
        "+886 2-2508-1885",
        "+886 2-2516-6626"
      ],
      email: "vecotaipei@mofa.gov.vn"
    },
    "united kingdom": {
      missionName: "British Office Taipei",
      address: "26F, President International Tower, 9-11 Song Gao Road, Xinyi District, Taipei 11073, Taiwan",
      officeLines: [
        "+886 (2) 8758 2088"
      ],
      emergencyPhone: "+44 (0)20 7008 5000"
    },
    "united states": {
      missionName: "American Institute in Taiwan (AIT), Taipei",
      address: "No. 100 Jinhu Road, Neihu District 11461, Taipei City, Taiwan",
      officeLines: [
        "+886 2-2162-2000 ext. 2306"
      ],
      emergencyPhone: "+886 2-2162-2000",
      email: "TaipeiACS@state.gov"
    },
    australia: {
      missionName: "Australian Office, Taipei",
      address: "The President International Tower, 27th-28th Floors, No. 9-11 Songgao Road, Taipei, Taiwan 11073",
      officeLines: [
        "+886 2 8725 4100"
      ]
    }
  },
  india: {
    malaysia: {
      missionName: "High Commission of Malaysia, New Delhi",
      address: "50-M Satya Marg, Chanakyapuri, New Delhi, India",
      officeLines: [
        "+91-11-2415 9300"
      ],
      email: "mwdelhi@kln.gov.my"
    },
    brunei: {
      missionName: "High Commission of Brunei Darussalam, New Delhi",
      address: "E-11/9, Vasant Vihar, New Delhi 110057, Republic of India",
      officeLines: [
        "+91 11 4328 1174",
        "+91 11 4328 1175",
        "+91 11 4328 1169",
        "+91 11 4107 0181",
        "+91 97171 84853 (hotline)"
      ],
      email: "newdelhi.india@mfa.gov.bn"
    },
    singapore: {
      missionName: "High Commission of the Republic of Singapore, New Delhi",
      address: "E-6 Chandragupta Marg, Chanakyapuri, New Delhi 110021, India",
      officeLines: [
        "+91 11 4600 0915"
      ],
      emergencyPhone: "+91 98102 03595 (Duty Officer, after office hours)",
      email: "singhc_del@mfa.sg"
    },
    indonesia: {
      missionName: "Embassy of the Republic of Indonesia, New Delhi",
      address: "50-A Kautilya Marg, Chanakyapuri, New Delhi, India",
      officeLines: [
        "+91-11-2611 8642-46"
      ],
      emergencyPhone: "+62-812-9007-0027",
      email: "pelindunganwni@kemlu.go.id"
    },
    thailand: {
      missionName: "Royal Thai Embassy, New Delhi",
      address: "56-N Nyaya Marg, Chanakyapuri, New Delhi 110021, India",
      officeLines: [
        "+91 11 2419 7200",
        "+91 11 2419 7156"
      ],
      email: "thaiembassy.del@mfa.go.th"
    },
    philippines: {
      missionName: "Embassy of the Philippines, New Delhi",
      address: "50-N Nyaya Marg, Chanakyapuri, New Delhi 110021, India",
      officeLines: [
        "+91-92204-05387 (Consular Section, WhatsApp)"
      ]
    },
    vietnam: {
      missionName: "Embassy of the Socialist Republic of Vietnam in India",
      address: "EP-7A, Chandragupta Marg, Chanakyapuri, New Delhi 110021, India",
      officeLines: [
        "+91 11-2687-9868"
      ],
      emergencyPhone: "+91 704-203-5588",
      email: "office@vietnamembassydelhi.in"
    },
    china: {
      missionName: "Embassy of the People's Republic of China in the Republic of India",
      address: "50-D, Shantipath, Chanakyapuri, New Delhi 110021, India",
      officeLines: [
        "+91 11 2611 2345",
        "+91 11 2467 5559"
      ],
      email: "chinaemb_in@mfa.gov.cn"
    },
    japan: {
      missionName: "Embassy of Japan in India",
      address: "50-G, Chanakyapuri, New Delhi 110021, India",
      officeLines: [
        "(91-11) 2687-6564",
        "(91-11) 2687-6581"
      ]
    },
    "united kingdom": {
      missionName: "British High Commission New Delhi",
      address: "Shantipath, Chanakyapuri, New Delhi 110 021, India",
      officeLines: [
        "+91 (11) 2419 2100"
      ],
      emergencyPhone: "+44 (0)20 7008 1500"
    },
    "united states": {
      missionName: "U.S. Embassy New Delhi",
      address: "Shantipath, Chanakyapuri, New Delhi - 110021, India",
      officeLines: [
        "+91 11 2419-8000"
      ],
      emergencyPhone: "+91 11 2419-8000",
      email: "acsnd@state.gov"
    },
    australia: {
      missionName: "Australian High Commission, India",
      address: "1/50 G, Shantipath, Chanakyapuri, New Delhi 110021, India",
      officeLines: [
        "+91 11 4139 9900"
      ],
      emergencyPhone: "+61 2 6261 3305",
      email: "ahc.newdelhi@dfat.gov.au"
    },
    "south korea": {
      missionName: "Embassy of the Republic of Korea in New Delhi",
      address: "9 Chandragupta Marg, Chanakyapuri Extension, New Delhi-110021, India",
      officeLines: [
        "+91-11-4200-7000"
      ],
      email: "india@mofa.go.kr"
    }
  },
  australia: {
    malaysia: {
      missionName: "High Commission of Malaysia, Canberra",
      address: "7 Perth Avenue, Yarralumla, ACT 2600, Australia",
      officeLines: [
        "+61 2 6120 0300"
      ],
      emergencyPhone: "+61 416 334 901",
      email: "mwcanberra@kln.gov.my"
    },
    brunei: {
      missionName: "High Commission of Brunei Darussalam, Canberra",
      address: "10 Beale Crescent, Deakin, ACT 2600, Canberra, Australia (Postal: P.O. Box 109, Curtin ACT 2605)",
      officeLines: [
        "+61 2 6285 4500",
        "+61 2 6285 4501",
        "+61 2 6285 4502",
        "+61 2 6285 4503"
      ],
      emergencyPhone: "+61 417 993 598 (hotline; mission states it is not a 24-hour service)",
      email: "canberra.australia@mfa.gov.bn"
    },
    singapore: {
      missionName: "High Commission of the Republic of Singapore, Canberra",
      officeLines: [
        "+61 2 6271 2000"
      ],
      emergencyPhone: "+61 414 733 944 (Duty Officer, Singaporeans only, after hours)",
      email: "CitizenService_CBR@mfa.sg"
    },
    indonesia: {
      missionName: "Embassy of the Republic of Indonesia, Canberra",
      address: "8 Darwin Avenue, Yarralumla, Canberra, ACT 2600, Australia",
      officeLines: [
        "+61 2 6250 8600"
      ],
      emergencyPhone: "+62-812-9007-0027",
      email: "pelindunganwni@kemlu.go.id"
    },
    thailand: {
      missionName: "Royal Thai Embassy, Canberra",
      address: "111 Empire Circuit, Yarralumla, ACT 2600, Australia",
      officeLines: [
        "+61 2 6206 0100"
      ],
      email: "thaiembassy.can@mfa.go.th"
    },
    vietnam: {
      missionName: "Embassy of the Socialist Republic of Vietnam in Australia",
      address: "6 Timbarra Crescent, O'Malley, ACT 2606, Australia",
      officeLines: [
        "+61 2-6169-4916",
        "+61 2-6169-4915",
        "+61 2-6169-4917"
      ],
      email: "vembassy@iinet.net.au"
    },
    china: {
      missionName: "Embassy of the People's Republic of China in Australia",
      address: "15 Coronation Drive, Yarralumla, ACT 2600, Australia",
      email: "chinaemb_au@mfa.gov.cn"
    },
    japan: {
      missionName: "Embassy of Japan in Australia",
      address: "112 Empire Circuit, Yarralumla, Canberra A.C.T. 2600, Australia",
      officeLines: [
        "(61-2) 6273-3244"
      ]
    },
    india: {
      missionName: "High Commission of India, Canberra, Australia",
      address: "15 Tench Street, Kingston ACT 2604, Australia",
      officeLines: [
        "+61 2 6225 4900",
        "+61-2-62254920",
        "+61-2-62254924",
        "+61-2-62254940",
        "+61-2-62254918",
        "+61-2-62254941"
      ],
      email: "ppt.canberra@mea.gov.in"
    },
    "united kingdom": {
      missionName: "British High Commission, Canberra",
      address: "Commonwealth Avenue, Yarralumla, ACT 2600, Australia",
      officeLines: [
        "+61 (0)2 6270 6666"
      ]
    },
    "united states": {
      missionName: "U.S. Embassy Canberra",
      address: "Moonah Place, Yarralumla, ACT 2600, Australia",
      officeLines: [
        "+61 2 6214-5600"
      ],
      emergencyPhone: "+61 2 411-424-608"
    },
    "south korea": {
      missionName: "Embassy of the Republic of Korea in the Commonwealth of Australia",
      address: "113 Empire Circuit, Yarralumla ACT 2600, Australia",
      officeLines: [
        "+61-2-6270-4100",
        "+61-2-6270-4151",
        "+61-2-6270-4153"
      ],
      emergencyPhone: "+61-408-815-922"
    }
  },
  "new zealand": {
    malaysia: {
      missionName: "High Commission of Malaysia, Wellington",
      address: "10 Washington Avenue, Brooklyn, Wellington, New Zealand",
      officeLines: [
        "+64-4-385 2439"
      ],
      email: "mwwellington@kln.gov.my"
    },
    brunei: {
      missionName: "High Commission of Brunei Darussalam, Canberra (non-resident, concurrently accredited to New Zealand)",
      address: "10 Beale Crescent, Deakin, ACT 2600, Canberra, Australia (Postal: P.O. Box 109, Curtin ACT 2605)",
      officeLines: [
        "+61 2 6285 4500",
        "+61 2 6285 4501",
        "+61 2 6285 4502",
        "+61 2 6285 4503"
      ],
      emergencyPhone: "+61 417 993 598 (hotline; mission states it is not a 24-hour service)",
      email: "canberra.australia@mfa.gov.bn"
    },
    singapore: {
      missionName: "High Commission of the Republic of Singapore, Wellington",
      address: "17 Kabul Street, Khandallah, Wellington 6035, New Zealand",
      officeLines: [
        "+64 4 470 0850"
      ],
      email: "singhc_wlg@mfa.sg"
    },
    indonesia: {
      missionName: "Embassy of the Republic of Indonesia, Wellington",
      address: "70 Glen Road, Kelburn, Wellington, New Zealand",
      officeLines: [
        "+64-4-475 8697/98/99"
      ],
      emergencyPhone: "+62-812-9007-0027",
      email: "pelindunganwni@kemlu.go.id"
    },
    thailand: {
      missionName: "Royal Thai Embassy, Wellington",
      address: "110 Molesworth Street, Thorndon, Wellington 6011, New Zealand",
      officeLines: [
        "+64 4 496-2900",
        "+64 4 476-8616"
      ],
      email: "visa@thaiembassynz.org.nz"
    },
    philippines: {
      missionName: "Philippine Embassy, Wellington",
      address: "50 Hobson Street, Thorndon, Wellington 6011, New Zealand",
      officeLines: [
        "+64-4-890-3741",
        "+64-4-890-3742",
        "+64-4-890-3743",
        "+64-4-890-3744"
      ],
      emergencyPhone: "+64-4-22-074-6517 (5pm-9am weekdays, and anytime weekends/public holidays)",
      email: "wellington.pe@philembassy.org.nz"
    },
    vietnam: {
      missionName: "Embassy of the Socialist Republic of Vietnam in New Zealand",
      address: "Level 21, Grand Plimmer Tower, 2-6 Gilmer Terrace, Wellington 6011, New Zealand",
      officeLines: [
        "+64 4-473-5910",
        "+64 4-473-5912"
      ],
      emergencyPhone: "+64 27-925-0185",
      email: "vnemb.nz@mofa.gov.vn"
    },
    china: {
      missionName: "Embassy of the People's Republic of China, Wellington",
      address: "No. 2-6 Glenmore Street, Wellington, New Zealand",
      officeLines: [
        "+64 4 472 1382"
      ],
      email: "info@chinaembassy.org.nz"
    },
    japan: {
      missionName: "Embassy of Japan in New Zealand",
      address: "Level 18, Majestic Centre, 100 Willis Street, Wellington 1, New Zealand (P.O. Box 6340)",
      officeLines: [
        "(64-4) 473-1540"
      ]
    },
    india: {
      missionName: "High Commission of India, Wellington, New Zealand",
      address: "72 Pipitea Street, Thorndon, Wellington 6011 (P.O. Box 12211)",
      officeLines: [
        "+64 4-473-6390"
      ],
      emergencyPhone: "+64-21-539817",
      email: "hoc.wellington@mea.gov.in"
    },
    "united kingdom": {
      missionName: "British High Commission Wellington",
      address: "44 Hill Street, Thorndon, Wellington 6011, New Zealand",
      officeLines: [
        "+64 (0)4 924 2888"
      ],
      emergencyPhone: "+44 (0)20 7008 5000"
    },
    "united states": {
      missionName: "U.S. Embassy Wellington",
      address: "29 Fitzherbert Terrace, Thorndon, Wellington, New Zealand",
      officeLines: [
        "+64 4 462-6000"
      ],
      emergencyPhone: "+64 4 462-6000"
    },
    australia: {
      missionName: "Australian High Commission, New Zealand",
      address: "72-76 Hobson Street, Thorndon, Wellington 6011, New Zealand",
      officeLines: [
        "+64 4 473 6411"
      ],
      emergencyPhone: "+61 2 6261 3305"
    },
    "south korea": {
      missionName: "Embassy of the Republic of Korea in Wellington",
      address: "Level 20, ANZ Centre, 171 Featherston Street, Wellington 6011, New Zealand",
      officeLines: [
        "+64-4-473-9073"
      ],
      emergencyPhone: "+64-21-0269-3271",
      email: "info-nz@mofa.go.kr"
    }
  },
  "united kingdom": {
    malaysia: {
      missionName: "High Commission of Malaysia, London",
      address: "45-46 Belgrave Square, London SW1X 8QT, United Kingdom",
      officeLines: [
        "+44 (0)20 3931 6196"
      ],
      email: "mwlondon@kln.gov.my"
    },
    brunei: {
      missionName: "High Commission of Brunei Darussalam, London",
      address: "19-20 Belgrave Square, London SW1X 8PG, United Kingdom",
      officeLines: [
        "+44 20 7581 0521",
        "+44 7481 270501 (hotline)"
      ],
      emergencyPhone: "+44 7770 360934 (consular line)",
      email: "london.uk@mfa.gov.bn"
    },
    singapore: {
      missionName: "High Commission of the Republic of Singapore, London",
      officeLines: [
        "+44 20 7235 8315"
      ],
      emergencyPhone: "+44 7710 348 335 (Duty Officer, Singaporeans only, arrest/repatriation/severe illness)",
      email: "singhc_lon@mfa.sg"
    },
    indonesia: {
      missionName: "Embassy of the Republic of Indonesia, London",
      address: "30 Great Peter Street, London SW1P 2BU, United Kingdom",
      officeLines: [
        "(44-20) 7499 7661",
        "(44-20) 7290 9600"
      ],
      emergencyPhone: "+62-812-9007-0027",
      email: "pelindunganwni@kemlu.go.id"
    },
    thailand: {
      missionName: "Royal Thai Embassy, London",
      address: "29-30 Queen's Gate, London SW7 5JB, United Kingdom",
      officeLines: [
        "+44 20 7589 2944"
      ],
      email: "consular.lon@mfa.go.th"
    },
    philippines: {
      missionName: "Embassy of the Republic of the Philippines, London",
      address: "6-11 Suffolk Street, London SW1Y 4HG, United Kingdom",
      officeLines: [
        "+44-20-7451-1780"
      ],
      emergencyPhone: "+44-78-0279-0695"
    },
    vietnam: {
      missionName: "Embassy of the Socialist Republic of Vietnam in the United Kingdom",
      address: "12-14 Victoria Road, London W8 5RD, United Kingdom",
      officeLines: [
        "+44 20-7937-1912"
      ],
      email: "vanphong@vietnamembassy.org.uk"
    },
    china: {
      missionName: "Embassy of the People's Republic of China, London",
      address: "49 Portland Place, London W1B 1JL, United Kingdom",
      officeLines: [
        "+44 20 7299 8438 (passport & notarisation)",
        "+44 20 3915 2277 (visa affairs)"
      ],
      emergencyPhone: "+44 20 7299 8439 (consular protection hotline)",
      email: "political_uk@mfa.gov.cn"
    },
    japan: {
      missionName: "Embassy of Japan in the United Kingdom",
      address: "101-104 Piccadilly, London, W1J 7JT, United Kingdom",
      officeLines: [
        "(44-20) 7465-6500"
      ]
    },
    india: {
      missionName: "High Commission of India, London, United Kingdom",
      address: "India House, Aldwych, London, WC2B 4NA",
      officeLines: [
        "(020) 7836 8484",
        "020-7632 3026",
        "020-7632 3087",
        "020 7632 3217",
        "020 7632 3134"
      ],
      email: "fs.cons@hcilondon.in"
    },
    "united states": {
      missionName: "U.S. Embassy London",
      address: "24 Grosvenor Square, London, W1A 2LQ, United Kingdom",
      officeLines: [
        "+44 20 7499-9000"
      ],
      emergencyPhone: "+44 20 7499-9000",
      email: "SCSLondon@state.gov"
    },
    australia: {
      missionName: "Australian High Commission, United Kingdom",
      address: "Australia House, Strand, London, WC2B 4LA, United Kingdom",
      officeLines: [
        "+44 20 7379 4334",
        "+44 20 7887 5776"
      ]
    },
    "south korea": {
      missionName: "Embassy of the Republic of Korea in the United Kingdom",
      address: "60 Buckingham Gate, London SW1E 6AJ"
    }
  },
  ireland: {
    malaysia: {
      missionName: "Embassy of Malaysia, Dublin",
      address: "Level 3A-5A, Shelbourne House, Shelbourne Road, Ballsbridge, Dublin, Ireland",
      officeLines: [
        "+353-1-667 7280"
      ],
      email: "mwdublin@kln.gov.my"
    },
    brunei: {
      missionName: "High Commission of Brunei Darussalam, London (non-resident, concurrently accredited to Ireland)",
      address: "19-20 Belgrave Square, London SW1X 8PG, United Kingdom",
      officeLines: [
        "+44 20 7581 0521",
        "+44 7481 270501 (hotline)"
      ],
      emergencyPhone: "+44 7770 360934 (consular line)",
      email: "london.uk@mfa.gov.bn"
    },
    singapore: {
      missionName: "Honorary Consulate-General of the Republic of Singapore, Dublin"
    },
    philippines: {
      missionName: "Philippine Consulate in Dublin",
      address: "John Bosco Youth Centre, Drimnagh, Dublin 12, Ireland",
      officeLines: []
    },
    japan: {
      missionName: "Embassy of Japan in Ireland",
      address: "Nutley Building, Merrion Centre, Nutley Lane, Dublin 4, Ireland",
      officeLines: [
        "(353-1) 202-8300"
      ]
    },
    india: {
      missionName: "Embassy of India, Dublin, Ireland",
      address: "69, Merrion Road, Ballsbridge, Dublin-4, D04 ER85",
      officeLines: [
        "+353-1-2060946",
        "+353-1-2830771"
      ],
      email: "hoc.dublin@mea.gov.in"
    },
    "united kingdom": {
      missionName: "British Embassy Dublin",
      address: "29 Merrion Road, Ballsbridge, Dublin D04 P272, Ireland",
      officeLines: [
        "+353 1 205 3700"
      ],
      email: "Press.Dublin@fcdo.gov.uk"
    },
    "united states": {
      missionName: "U.S. Embassy Dublin",
      address: "42 Elgin Road, Ballsbridge, Dublin 4, Ireland",
      officeLines: [
        "+353-1-668-8777"
      ],
      emergencyPhone: "+353-1-668-8777"
    },
    australia: {
      missionName: "Australian Embassy, Ireland",
      address: "3rd Floor, 47-49 St Stephen's Green, Dublin 2, D02 W634, Ireland",
      officeLines: [
        "+353 1 664 5300"
      ],
      emergencyPhone: "+61 2 6261 3305"
    },
    "south korea": {
      missionName: "Embassy of the Republic of Korea in Ireland",
      address: "72 Merrion Square South, Dublin 2, D02 TW54, Ireland"
    }
  },
  france: {
    malaysia: {
      missionName: "Embassy of Malaysia, Paris",
      address: "Tour Voltaire, 8th Floor, 1 Place des Degrés, Puteaux, France",
      officeLines: [
        "+33 1 45 53 11 85"
      ],
      emergencyPhone: "+33 6 32 44 65 71",
      email: "mwparis@kln.gov.my"
    },
    brunei: {
      missionName: "Embassy of Brunei Darussalam, Paris",
      address: "7 Rue de Presbourg, 75116 Paris, France",
      officeLines: [
        "+33 1 5364 6760",
        "+33 1 5364 6761",
        "+33 6 49 15 42 27 (hotline)"
      ],
      email: "paris.france@mfa.gov.bn"
    },
    singapore: {
      missionName: "Embassy of the Republic of Singapore, Paris",
      address: "16 Rue Murillo, 75008 Paris, France",
      officeLines: [
        "+33 1 56 79 68 00"
      ],
      emergencyPhone: "+33 6 75 03 25 55 (duty consular number)",
      email: "singemb_par@mfa.sg"
    },
    indonesia: {
      missionName: "Embassy of the Republic of Indonesia, Paris",
      address: "47-49 Rue Cortambert, 75116 Paris, France",
      officeLines: [
        "(33-1) 4503 0760"
      ],
      emergencyPhone: "+62-812-9007-0027",
      email: "pelindunganwni@kemlu.go.id"
    },
    thailand: {
      missionName: "Royal Thai Embassy, Paris",
      address: "8, rue Greuze, 75116 Paris, France",
      officeLines: [
        "+33 1 5626 5050"
      ],
      email: "visa.par@mfa.go.th"
    },
    philippines: {
      missionName: "Philippine Embassy, Paris",
      address: "45 rue du Ranelagh, 75016 Paris, France",
      officeLines: [
        "+33-1-44-14-57-00"
      ],
      emergencyPhone: "+33-6-20-59-25-15"
    },
    vietnam: {
      missionName: "Embassy of the Socialist Republic of Vietnam in France",
      address: "62 Rue Boileau, 75016 Paris, France",
      officeLines: [
        "+33 1-44146400",
        "+33 1-45243948"
      ],
      email: "vnemb.fr@mofa.gov.vn"
    },
    china: {
      missionName: "Embassy of the People's Republic of China, Paris",
      address: "20 Rue Monsieur, 75007 Paris, France",
      officeLines: [
        "+33 1 4952 1950"
      ]
    },
    japan: {
      missionName: "Embassy of Japan in France",
      address: "7, Avenue Hoche, 75008 Paris, France",
      officeLines: [
        "(33-1) 4888-6200"
      ]
    },
    india: {
      missionName: "Embassy of India, Paris, France (and Principality of Monaco)",
      address: "13-15 Rue Alfred Dehodencq, 75016 Paris (Chancery); Consular Section: 20-22 Rue Alberic Magnard, 75016 Paris",
      officeLines: [
        "00 33 1 40 50 70 70",
        "00 33 1 40 50 71 71",
        "00 33 1 40 50 51 08"
      ],
      emergencyPhone: "+33 6 48 34 00 63",
      email: "cons.paris@mea.gov.in"
    },
    "united kingdom": {
      missionName: "British Embassy Paris",
      address: "35 Rue du Faubourg St Honoré, 75008 Paris, France",
      officeLines: [
        "+33 (0)1 44 51 31 00"
      ],
      emergencyPhone: "+44 (0)20 7008 5000"
    },
    "united states": {
      missionName: "U.S. Embassy Paris",
      address: "2 Avenue Gabriel, 75008 Paris, France",
      officeLines: [
        "+33 1 43-12-22-22"
      ],
      emergencyPhone: "+33 1 43-12-22-22 (press 0, ask for duty officer)",
      email: "Citizeninfo@state.gov"
    },
    australia: {
      missionName: "Australian Embassy, France",
      address: "4, rue Jean Rey, 75724 Paris Cedex 15, France",
      officeLines: [
        "+33 1 40 59 33 00"
      ]
    }
  },
  germany: {
    malaysia: {
      missionName: "Embassy of Malaysia, Berlin",
      address: "Klingelhöferstraße 6, 10785 Berlin, Germany",
      officeLines: [
        "+49 (0)30 885 749-0"
      ],
      emergencyPhone: "+49 (0)160 9188 3622",
      email: "mwberlin@kln.gov.my"
    },
    brunei: {
      missionName: "Embassy of Brunei Darussalam, Berlin",
      address: "Kronenstraße 55-58, 10117 Berlin, Federal Republic of Germany",
      officeLines: [
        "+49 30 2060 7600",
        "+49 175 640 4040 (hotline)"
      ],
      email: "berlin.germany@mfa.gov.bn"
    },
    singapore: {
      missionName: "Embassy of the Republic of Singapore, Berlin",
      address: "Voßstraße 17, 10117 Berlin, Germany",
      officeLines: [
        "+49 30 226 343-0"
      ],
      emergencyPhone: "+49 15 2234 12182 (Duty Officer)",
      email: "singemb_ber@mfa.sg"
    },
    indonesia: {
      missionName: "Embassy of the Republic of Indonesia, Berlin",
      address: "Clara-Wieck-Straße 1, 10785 Berlin, Germany",
      officeLines: [
        "+49-30-47807-200"
      ],
      emergencyPhone: "+62-812-9007-0027",
      email: "pelindunganwni@kemlu.go.id"
    },
    thailand: {
      missionName: "Royal Thai Embassy, Berlin",
      address: "Lepsiusstrasse 64/66, 12163 Berlin, Germany",
      officeLines: [
        "+49 30 794 810",
        "+49 30 794 81117"
      ],
      email: "general@thaiembassy.de"
    },
    philippines: {
      missionName: "Embassy of the Republic of the Philippines, Berlin",
      address: "Luisenstrasse 16, 10117 Berlin-Mitte, Germany",
      officeLines: [
        "+49-30-864-9500"
      ],
      emergencyPhone: "+49-173-521-5703 / +49-173-421-7750"
    },
    vietnam: {
      missionName: "Embassy of the Socialist Republic of Vietnam in Germany",
      address: "Elsenstraße 3, 12435 Berlin, Germany",
      officeLines: [
        "+49 30-53630108"
      ],
      email: "sqvnberlin@t-online.de"
    },
    china: {
      missionName: "Embassy of the People's Republic of China, Berlin",
      address: "Märkisches Ufer 54, 10179 Berlin, Germany",
      officeLines: [
        "+49 30 275880"
      ]
    },
    japan: {
      missionName: "Embassy of Japan in Germany",
      address: "Hiroshimastrasse 6, 10785 Berlin, Germany",
      officeLines: [
        "(49-30) 210940"
      ]
    },
    india: {
      missionName: "Embassy of India, Berlin, Germany",
      address: "Tiergartenstrasse 17, 10785 Berlin, Germany",
      officeLines: [
        "+49 30 25795 0",
        "+49 30 2579 5820"
      ],
      emergencyPhone: "+49 151 7212 0983",
      email: "cons.berlin@mea.gov.in"
    },
    "united kingdom": {
      missionName: "British Embassy Berlin",
      address: "Wilhelmstraße 70/71, 10117 Berlin, Germany",
      officeLines: [
        "+49 (0)30 204570"
      ],
      emergencyPhone: "+44 (0)20 7008 5000"
    },
    "united states": {
      missionName: "U.S. Embassy Berlin",
      address: "Clayallee 170, 14191 Berlin, Germany",
      officeLines: [
        "+49 69 7535-2100"
      ],
      emergencyPhone: "+49 30 8305-0",
      email: "ACSBerlin@state.gov"
    },
    australia: {
      missionName: "Australian Embassy, Germany",
      address: "Wallstraße 76-79, 10179 Berlin, Germany",
      officeLines: [
        "+49 30 880088 0"
      ],
      emergencyPhone: "+61 2 6261 3305",
      email: "info.berlin@dfat.gov.au"
    }
  },
  italy: {
    malaysia: {
      missionName: "Embassy of Malaysia, Rome",
      address: "Via Cimone 48, 00141 Roma, Italy",
      officeLines: [
        "+39-06-2418658"
      ],
      email: "mwrome@kln.gov.my"
    },
    brunei: {
      missionName: "Embassy of Brunei Darussalam, Paris (non-resident, concurrently accredited to Italy)",
      address: "7 Rue de Presbourg, 75116 Paris, France",
      officeLines: [
        "+33 1 5364 6760",
        "+33 1 5364 6761",
        "+33 6 49 15 42 27 (hotline)"
      ],
      email: "paris.france@mfa.gov.bn"
    },
    singapore: {
      missionName: "Honorary Consulate-General of the Republic of Singapore, Rome"
    },
    indonesia: {
      missionName: "Embassy of the Republic of Indonesia, Rome",
      address: "Via Campania 55, 00187 Roma, Italy",
      officeLines: [
        "+39 06 4200911"
      ],
      emergencyPhone: "+62-812-9007-0027",
      email: "pelindunganwni@kemlu.go.id"
    },
    thailand: {
      missionName: "Royal Thai Embassy, Rome",
      address: "Via Nomentana 132, 00162 Rome, Italy",
      officeLines: [
        "+39 06 8622-051"
      ],
      email: "info@ambthai.it"
    },
    philippines: {
      missionName: "Embassy of the Philippines in Italy, Rome",
      address: "Via Aurelia 290/A, 00165 Rome, Italy",
      officeLines: [
        "+39-06-397-46621",
        "+39-333-816-0487 (Hotline)"
      ],
      emergencyPhone: "+39-334-658-2118 (deaths, repatriation, travel documents)"
    },
    vietnam: {
      missionName: "Embassy of the Socialist Republic of Vietnam in Italy",
      address: "Via di Bravetta 156, 00164 Rome, Italy",
      officeLines: [
        "+39 06-6160726",
        "+39 06-66162504"
      ],
      email: "vnemb.it@mofa.gov.vn"
    },
    japan: {
      missionName: "Embassy of Japan in Italy",
      address: "Via Quintino Sella, 60, 00187 Roma, Italy",
      officeLines: [
        "(39-06) 48799-1"
      ]
    },
    india: {
      missionName: "Embassy of India, Rome",
      address: "Via XX Settembre, 5, 00187 Rome, Italy",
      officeLines: [
        "+39 06 4884642",
        "+39 06 4884643",
        "+39 06 4884644",
        "+39 06 4884645"
      ],
      emergencyPhone: "+39 331 614 2085",
      email: "hoc.rome@mea.gov.in"
    },
    "united kingdom": {
      missionName: "British Embassy Rome",
      address: "Via XX Settembre 80/a, 00187 Rome, Italy",
      officeLines: [
        "+39 06 4220 0001"
      ],
      emergencyPhone: "+44 (0)20 7008 5000"
    },
    "united states": {
      missionName: "U.S. Embassy Rome",
      address: "Via Vittorio Veneto 119/A, 00187 Rome, Italy",
      officeLines: [
        "+39-06-46741"
      ],
      emergencyPhone: "+39-06-46741",
      email: "uscitizensrome@state.gov"
    },
    australia: {
      missionName: "Australian Embassy, Italy",
      address: "Via Antonio Bosio, 5, 00161 Rome, Italy",
      officeLines: [
        "+39 06 8527 21"
      ],
      emergencyPhone: "+61 2 6261 3305"
    }
  },
  spain: {
    malaysia: {
      missionName: "Embassy of Malaysia, Madrid",
      address: "Avenida de los Madroños 63 bis, Madrid, Spain",
      officeLines: [
        "+34 91 555 0684"
      ],
      emergencyPhone: "+34 659 89 49 43",
      email: "mwmadrid@kln.gov.my"
    },
    brunei: {
      missionName: "Embassy of Brunei Darussalam, Paris (non-resident, concurrently accredited to Spain)",
      address: "7 Rue de Presbourg, 75116 Paris, France",
      officeLines: [
        "+33 1 5364 6760",
        "+33 1 5364 6761",
        "+33 6 49 15 42 27 (hotline)"
      ],
      email: "paris.france@mfa.gov.bn"
    },
    singapore: {
      missionName: "Honorary Consulate-General of the Republic of Singapore, Madrid"
    },
    indonesia: {
      missionName: "Embassy of the Republic of Indonesia, Madrid",
      address: "Calle de Agastia No. 65, 28043 Madrid, Spain",
      officeLines: [
        "(34-91) 413-0294",
        "(34-91) 413-0394",
        "(34-91) 413-0594",
        "(34-91) 413-0747"
      ],
      emergencyPhone: "+62-812-9007-0027",
      email: "pelindunganwni@kemlu.go.id"
    },
    thailand: {
      missionName: "Royal Thai Embassy, Madrid",
      address: "Calle Joaquín Costa 29, 28002 Madrid, Spain",
      officeLines: [
        "+34 91 563 2903"
      ],
      email: "consuladotailandia@gmail.com"
    },
    philippines: {
      missionName: "Philippine Embassy, Madrid",
      address: "Calle Eresma 2, 28002 Madrid, Spain",
      officeLines: [
        "+34-917-82-38-30",
        "+34-910-55-22-29",
        "+34-917-82-38-32"
      ],
      emergencyPhone: "+34-616-49-18-61 (Consular Section)",
      email: "madrid.pe@dfa.gov.ph"
    },
    vietnam: {
      missionName: "Embassy of the Socialist Republic of Vietnam in Spain",
      address: "Avenida de Alfonso XIII, 54, 28016 Madrid, Spain",
      officeLines: [
        "+34 91-5102867",
        "+34 91-4157067"
      ],
      email: "vnemb.es@mofa.gov.vn"
    },
    japan: {
      missionName: "Embassy of Japan in Spain",
      address: "Calle Serrano, 109, 28006 Madrid, Spain",
      officeLines: [
        "(34) 91-590-7600"
      ]
    },
    india: {
      missionName: "Embassy of India, Madrid",
      address: "Avenida Pío XII, 30-32, 28016 Madrid, Spain",
      officeLines: [
        "+34 91 309 8882"
      ],
      emergencyPhone: "+34 632 813 288",
      email: "amb.madrid@mea.gov.in"
    },
    "united kingdom": {
      missionName: "British Embassy Madrid",
      address: "Torre Emperador Castellana, Paseo de la Castellana 259D, 28046 Madrid, Spain",
      emergencyPhone: "+44 (0)20 7008 5000"
    },
    "united states": {
      missionName: "U.S. Embassy Madrid",
      address: "Calle Serrano, 75, 28006 Madrid, Spain",
      officeLines: [
        "+34 91 587 2240"
      ],
      emergencyPhone: "+34 91 587 2200 (ask for duty officer)",
      email: "askacs@state.gov"
    },
    australia: {
      missionName: "Australian Embassy, Spain",
      address: "Torre Emperador, Paseo de la Castellana, 259D, Planta 24, 28046 Madrid, Spain",
      officeLines: [
        "+34 91 353 6600"
      ],
      emergencyPhone: "+61 2 6261 3305"
    }
  },
  netherlands: {
    malaysia: {
      missionName: "Embassy of Malaysia, The Hague",
      address: "Rustenburgweg 2, Zuid-Holland, The Hague, Netherlands",
      officeLines: [
        "+31 70 350 6506"
      ],
      emergencyPhone: "+31 6 3448 5289",
      email: "mwthehague@kln.gov.my"
    },
    brunei: {
      missionName: "Embassy of Brunei Darussalam, Brussels (non-resident, concurrently accredited to the Netherlands)",
      address: "Avenue Franklin Roosevelt 47, 1000 Brussels, Kingdom of Belgium",
      officeLines: [
        "+32 2 675 0878",
        "+32 499 63 63 87 (hotline)"
      ],
      email: "brussels.belgium@mfa.gov.bn"
    },
    singapore: {
      missionName: "Embassy of the Republic of Singapore, Brussels (Ambassador to Belgium is concurrently accredited to the Netherlands, Luxembourg and the EU; covers consular matters for the Netherlands)",
      address: "85 Avenue Franklin Roosevelt, 1050 Brussels, Belgium",
      officeLines: [
        "+32 2 660 2979"
      ],
      email: "consvc@mfa.sg"
    },
    indonesia: {
      missionName: "Embassy of the Republic of Indonesia, The Hague (Den Haag)",
      address: "Tobias Asserlaan 8, 2517 KC Den Haag, Netherlands",
      officeLines: [
        "+31 70 310 8100"
      ],
      emergencyPhone: "+62-812-9007-0027",
      email: "pelindunganwni@kemlu.go.id"
    },
    thailand: {
      missionName: "Royal Thai Embassy, The Hague",
      address: "Laan Copes van Cattenburch 123, 2585 EZ The Hague, Netherlands",
      officeLines: [
        "+31 70 345 0766"
      ],
      email: "thehague@thaiembassy.nl"
    },
    philippines: {
      missionName: "Embassy of the Republic of the Philippines, The Hague",
      address: "Laan Copes van Cattenburch 125, 2585 EZ, The Hague, Netherlands",
      officeLines: [
        "+31-70-360-4820"
      ]
    },
    vietnam: {
      missionName: "Embassy of the Socialist Republic of Vietnam in the Netherlands",
      address: "Javastraat 1, 2585 AA The Hague, Netherlands",
      officeLines: [
        "+31 70-3648917"
      ],
      email: "thehague@vietembassy.nl"
    },
    china: {
      missionName: "Embassy of the People's Republic of China, The Hague",
      address: "Willem Lodewijklaan 10, 2517 JT The Hague, Netherlands",
      officeLines: [
        "+31 70 306 5099",
        "+31 6 5133 5779",
        "+31 6 1366 4691"
      ],
      email: "chinaemb_nl@mfa.gov.cn"
    },
    japan: {
      missionName: "Embassy of Japan in the Netherlands",
      address: "Tobias Asserlaan 5, 2517 KC, The Hague, Netherlands",
      officeLines: [
        "(31-70) 346-9544"
      ]
    },
    india: {
      missionName: "Embassy of India, The Hague",
      address: "Buitenrustweg 2, 2517 KD The Hague, Netherlands (Consular Wing: Oranjestraat 12, 2514 JB The Hague)",
      officeLines: [
        "+31 70 346 9771"
      ],
      emergencyPhone: "+31 6 43743800",
      email: "consular.thehague@mea.gov.in"
    },
    "united kingdom": {
      missionName: "British Embassy The Hague",
      address: "Lange Voorhout 10, 2514 ED The Hague, Netherlands",
      officeLines: [
        "+31 (0)70 427 0427"
      ],
      emergencyPhone: "+44 (0)20 7008 5000"
    },
    "united states": {
      missionName: "U.S. Embassy The Hague",
      address: "Lange Voorhout 102, 2514 EJ The Hague, Netherlands",
      officeLines: [
        "+31-70-310-2209"
      ],
      emergencyPhone: "+31-70-310-2209",
      email: "USCitizenServicesAms@state.gov"
    },
    australia: {
      missionName: "Australian Embassy, The Netherlands",
      address: "Carnegielaan 4, 2517 KH The Hague, The Netherlands",
      officeLines: [
        "+31 70 310 8200"
      ],
      emergencyPhone: "+61 2 6261 3305",
      email: "consular.thehague@dfat.gov.au"
    }
  },
  switzerland: {
    malaysia: {
      missionName: "Embassy of Malaysia, Berne",
      address: "Jungfraustrasse 1, CH-3005 Berne, Switzerland",
      officeLines: [
        "+41 (0)31 350 4700"
      ],
      emergencyPhone: "+41 (0)78 222 4486",
      email: "mwberne@kln.gov.my"
    },
    brunei: {
      missionName: "Permanent Mission of Brunei Darussalam to the UN, WTO and Other International Organisations, Geneva",
      address: "International Centre Cointrin (ICC), Block D, 5th Floor, Route de Pré-Bois 20, Case Postale 1806, 1215 Geneva 15, Switzerland",
      officeLines: [
        "+41 22 929 8240",
        "+41 79 738 2005 (hotline)"
      ],
      email: "geneva.switzerland@mfa.gov.bn"
    },
    singapore: {
      missionName: "Permanent Mission of the Republic of Singapore, Geneva (covers consular assistance for Switzerland; bilateral Ambassador to Switzerland is non-resident, accredited from Singapore)",
      officeLines: [
        "+41 22 795 0101"
      ],
      emergencyPhone: "+41 79 600 9833 (Duty Officer, after hours)",
      email: "MFA_GVA_WTO@mfa.gov.sg"
    },
    indonesia: {
      missionName: "Embassy of the Republic of Indonesia, Bern",
      address: "Elfenauweg 51, 3006 Bern, Switzerland",
      officeLines: [
        "+41 31 352 0983-85"
      ],
      emergencyPhone: "+62-812-9007-0027",
      email: "pelindunganwni@kemlu.go.id"
    },
    thailand: {
      missionName: "Royal Thai Embassy, Bern",
      address: "Kirchstrasse 56, 3097 Liebefeld-Bern, Switzerland",
      officeLines: [
        "+41 31 970 3030",
        "+41 31 970 3427"
      ],
      email: "thaiembassy.ben@mfa.go.th"
    },
    philippines: {
      missionName: "Embassy of the Republic of the Philippines, Berne",
      address: "Kirchenfeldstrasse 73-75, 3005 Berne, Switzerland",
      officeLines: [
        "+41-31-350-1700",
        "+41-31-350-1717",
        "+41-31-350-1716",
        "+41-31-350-1718",
        "+41-31-350-1719"
      ],
      emergencyPhone: "+41-79-542-1992 (Duty Officer)"
    },
    vietnam: {
      missionName: "Embassy of the Socialist Republic of Vietnam in Switzerland",
      address: "Schlösslistrasse 26, CH-3008 Bern, Switzerland",
      officeLines: [
        "+41 31-3887872",
        "+41 31-3887875"
      ],
      email: "vietsuisse@bluewin.ch"
    },
    japan: {
      missionName: "Embassy of Japan in Switzerland",
      address: "Engestrasse 53, 3012 Berne, Switzerland",
      officeLines: [
        "(41-31) 300-22-22"
      ]
    },
    china: {
      missionName: "Chinese Consulate General in Zurich",
      address: "Bellariastrasse 20, 8002 Zürich, Switzerland",
      officeLines: [
        "+41-44-2011005"
      ],
      email: "zurich@csm.mfa.gov.cn"
    },
    india: {
      missionName: "Embassy of India, Berne",
      address: "Kirchenfeldstrasse 28, 3005 Bern, Switzerland",
      officeLines: [
        "+41 31 350 1130"
      ],
      emergencyPhone: "+41 76 6996224",
      email: "hoc.berne@mea.gov.in"
    },
    "united kingdom": {
      missionName: "British Embassy Berne",
      address: "Thunstrasse 50, 3005 Berne, Switzerland",
      officeLines: [
        "+41 (0)31 359 77 00"
      ],
      emergencyPhone: "+44 (0)20 7008 5000"
    },
    "united states": {
      missionName: "U.S. Embassy Bern",
      address: "Sulgeneckstrasse 19, 3007 Bern, Switzerland",
      officeLines: [
        "+41 31 357 7011"
      ],
      emergencyPhone: "+41 31 357 7011",
      email: "bernacs@state.gov"
    },
    australia: {
      missionName: "Australian Embassy, Switzerland",
      address: "Weltpoststrasse 5, 2nd Floor, Flex Office 3015, Bern, Switzerland",
      officeLines: [
        "+41 31 310 1780"
      ]
    },
    "south korea": {
      missionName: "Embassy of the Republic of Korea to the Swiss Confederation",
      officeLines: [
        "+41-31-356-2444"
      ],
      email: "swiss@mofa.go.kr"
    }
  },
  "united states": {
    malaysia: {
      missionName: "Consulate General of Malaysia, New York",
      address: "313 East 43rd Street, New York, NY 10017, USA",
      officeLines: [
        "+1 (212) 490-2722"
      ],
      emergencyPhone: "+1 (929) 428-0794",
      email: "mwnewyorkcg@kln.gov.my"
    },
    brunei: {
      missionName: "Embassy of Brunei Darussalam, Washington D.C.",
      address: "3520 International Court NW, Washington D.C. 20008, United States of America",
      officeLines: [
        "+1 202 237 1838",
        "+1 202 725 5366 (hotline)"
      ],
      email: "washington.usa@mfa.gov.bn"
    },
    singapore: {
      missionName: "Embassy of the Republic of Singapore, Washington, D.C.",
      officeLines: [
        "+1 202 537 3100"
      ],
      email: "singemb_was@mfa.sg"
    },
    indonesia: {
      missionName: "Embassy of the Republic of Indonesia, Washington D.C.",
      address: "2020 Massachusetts Ave NW, Washington, DC 20036, United States",
      officeLines: [
        "+1 202-775-5200"
      ],
      emergencyPhone: "+62-812-9007-0027",
      email: "pelindunganwni@kemlu.go.id"
    },
    thailand: {
      missionName: "Royal Thai Embassy, Washington, D.C.",
      address: "1024 Wisconsin Avenue NW, Washington, DC 20007, United States",
      officeLines: [
        "+1 202 944-3600",
        "+1 202 684-8493"
      ],
      email: "thai.wsn@thaiembdc.org"
    },
    philippines: {
      missionName: "Embassy of the Republic of the Philippines, Washington, D.C.",
      address: "1600 Massachusetts Avenue NW, Washington, D.C. 20036, USA",
      officeLines: [
        "+1-202-467-9300",
        "+1-202-467-9363"
      ],
      emergencyPhone: "+1-202-368-2767 (Duty Officer); +1-202-769-8049 (Assistance to Nationals/VAW Desk)",
      email: "washington@phembassy-us.org"
    },
    vietnam: {
      missionName: "Embassy of the Socialist Republic of Vietnam in the United States of America",
      address: "1233 20th Street NW, Suite 400, Washington, DC 20036, USA",
      officeLines: [
        "+1 202-861-0737"
      ],
      emergencyPhone: "+1 202-739-1666",
      email: "vanphong@vietnamembassy.us"
    },
    china: {
      missionName: "Embassy of the People's Republic of China, Washington D.C.",
      address: "3505 International Place, N.W., Washington D.C. 20008, U.S.A.",
      officeLines: [
        "+1 202 495 2000"
      ],
      email: "chinaembpress_us@mfa.gov.cn"
    },
    japan: {
      missionName: "Embassy of Japan in the United States of America",
      address: "2520 Massachusetts Avenue, N.W., Washington D.C., 20008-2869, U.S.A.",
      officeLines: [
        "(1-202) 238-6700"
      ]
    },
    india: {
      missionName: "Embassy of India, Washington D.C.",
      address: "2107 Massachusetts Avenue, NW, Washington, DC 20008, USA",
      officeLines: [
        "+1 202 939 7000"
      ],
      emergencyPhone: "+1 202 939 9845 / +1 202 856 6945",
      email: "hoc.washington@mea.gov.in"
    },
    "united kingdom": {
      missionName: "British Embassy Washington",
      address: "3100 Massachusetts Avenue, NW, Washington DC 20008, USA",
      email: "public.affairsdc@fcdo.gov.uk"
    },
    australia: {
      missionName: "Australian Embassy, United States of America",
      address: "1601 Massachusetts Ave NW, Washington, DC 20036, United States",
      officeLines: [
        "+1 202 797 3000"
      ],
      emergencyPhone: "+61 2 6261 3305"
    },
    "south korea": {
      missionName: "Embassy of the Republic of Korea in the United States of America",
      address: "2450 Massachusetts Avenue N.W., Washington, D.C. 20008",
      officeLines: [
        "+1-202-939-5600"
      ],
      emergencyPhone: "+1-202-641-8761",
      email: "consular.usa@mofa.go.kr"
    }
  },
  canada: {
    malaysia: {
      missionName: "High Commission of Malaysia, Ottawa",
      address: "60 Boteler Street, Ottawa, Ontario K1N 8Y7, Canada",
      officeLines: [
        "+1 (613) 241-5182"
      ],
      emergencyPhone: "+1 (343) 254-4333",
      email: "mwottawa@kln.gov.my"
    },
    brunei: {
      missionName: "High Commission of Brunei Darussalam, Ottawa",
      address: "395 Laurier Avenue East, Ottawa, Ontario K1N 6R4, Canada",
      officeLines: [
        "+1 613 234 5656",
        "+1 613 234 4275",
        "+1 613 864 5654 (hotline)"
      ],
      email: "ottawa.canada@mfa.gov.bn"
    },
    thailand: {
      missionName: "Royal Thai Embassy, Ottawa",
      address: "180 Island Park Drive, Ottawa, Ontario K1Y 0A2, Canada",
      officeLines: [
        "+1 613 722-4444"
      ],
      emergencyPhone: "+1 613 853-2650",
      email: "contact@thaiembassy.ca"
    },
    philippines: {
      missionName: "Embassy of the Republic of the Philippines, Ottawa",
      address: "30 Murray Street, Ottawa, ON K1N 5M4, Canada",
      officeLines: [
        "+1-613-233-1121"
      ],
      emergencyPhone: "+1-613-614-2846 (cases of death or detention of a Filipino citizen)"
    },
    vietnam: {
      missionName: "Embassy of the Socialist Republic of Vietnam in Canada",
      address: "55 MacKay Street, Ottawa, ON K1M 2B2, Canada",
      officeLines: [
        "+1 613-236-0772"
      ],
      emergencyPhone: "+1 613-700-4779",
      email: "vietem-inter@uniserve.com"
    },
    japan: {
      missionName: "Embassy of Japan in Canada",
      address: "255 Sussex Drive, Ottawa, Ontario K1N 9E6, Canada",
      officeLines: [
        "(1-613) 241-8541"
      ]
    },
    china: {
      missionName: "Chinese Consulate General in Vancouver",
      address: "3380 Granville St., Vancouver, B.C. V6H 3K3, Canada",
      officeLines: [
        "001-604-734-7492",
        "001-604-736-5188"
      ]
    },
    india: {
      missionName: "High Commission of India, Ottawa",
      address: "10 Springfield Road, Ottawa, Ontario K1M 1C9, Canada",
      officeLines: [
        "+1 613 744 3751",
        "+1 613 744 3752",
        "+1 613 744 3753"
      ],
      emergencyPhone: "+1 613 899 4622",
      email: "hc.ottawa@mea.gov.in"
    },
    "united kingdom": {
      missionName: "British High Commission Ottawa",
      address: "140 Sussex Drive, Ottawa, Ontario K1N 5A2, Canada",
      officeLines: [
        "+1 613 237 1530"
      ],
      emergencyPhone: "+44 (0)20 7008 5000"
    },
    "united states": {
      missionName: "U.S. Embassy Ottawa",
      address: "490 Sussex Drive, Ottawa, Ontario K1N 1G8, Canada",
      officeLines: [
        "+1 613 688-5335"
      ],
      emergencyPhone: "+1 613 238-5335",
      email: "OttawaACS@state.gov"
    },
    australia: {
      missionName: "Australian High Commission, Canada",
      address: "Suite 1301, 50 O'Connor Street, 13th Floor, Ottawa, Ontario, K1P 6L2, Canada",
      officeLines: [
        "+1 613 236 0841"
      ],
      emergencyPhone: "+61 2 6261 3305"
    }
  },
  "united arab emirates": {
    malaysia: {
      missionName: "Consulate General of Malaysia, Dubai",
      address: "Villa 83, Street 10D, Mankhool, Bur Dubai, United Arab Emirates",
      officeLines: [
        "+971-4-398 5843"
      ],
      emergencyPhone: "+971 50 737 9196",
      email: "dxb.cons@kln.gov.my"
    },
    brunei: {
      missionName: "Embassy of Brunei Darussalam, Abu Dhabi",
      address: "Villa 2B2(8), As Silbar Street, Al Bateen, Abu Dhabi, United Arab Emirates (P.O. Box 5836)",
      officeLines: [
        "+971 2 448 6999",
        "+971 50 641 3478 (hotline)"
      ],
      email: "abudhabi.uae@mfa.gov.bn"
    },
    singapore: {
      missionName: "Embassy of the Republic of Singapore, Abu Dhabi",
      address: "Al Muhairy Centre, 8th Floor, Unit 803-804, Zayed the First Street, P.O. Box 112148, Abu Dhabi, UAE",
      officeLines: [
        "+971 2 222 2083"
      ],
      email: "singemb_auh@mfa.sg"
    },
    indonesia: {
      missionName: "Embassy of the Republic of Indonesia, Abu Dhabi",
      address: "Al Yaqout Street, Embassies District, Plot 42, Sector W59-02, Abu Dhabi, United Arab Emirates",
      officeLines: [
        "+971 2 445 4448"
      ],
      emergencyPhone: "+62-812-9007-0027",
      email: "pelindunganwni@kemlu.go.id"
    },
    thailand: {
      missionName: "Royal Thai Embassy, Abu Dhabi",
      address: "Villa No. 137, Al Ma'mourah Street, Al Nahyan Area, Abu Dhabi, United Arab Emirates",
      officeLines: [
        "+971 2 557 6551"
      ],
      email: "thaiauh@emirates.net.ae"
    },
    philippines: {
      missionName: "Embassy of the Republic of the Philippines, Abu Dhabi",
      address: "Villa 1, W-48, Street #8, Sector 2-23, Plot 51, Al Qubaisat, Abu Dhabi, UAE",
      officeLines: [
        "+971-50-443-8003",
        "+971-56-147-5871",
        "+971-56-236-8406"
      ],
      emergencyPhone: "+971-50-813-7836 (Duty Phone)"
    },
    vietnam: {
      missionName: "Embassy of the Socialist Republic of Vietnam in the United Arab Emirates",
      address: "Villa 147, Salama Bint Butti Street (Street 23), Al Mushrif, Abu Dhabi, UAE",
      officeLines: [
        "+971 2-4496710"
      ],
      email: "vnemb1@emirates.net.ae"
    },
    japan: {
      missionName: "Embassy of Japan in the United Arab Emirates",
      address: "Abu Dhabi, United Arab Emirates (P.O. Box 2430)",
      officeLines: [
        "(971-2) 443-5696"
      ]
    },
    india: {
      missionName: "Embassy of India, Abu Dhabi",
      address: "Plot No. 10, Sector W-59/02, Diplomatic Area, Off Sheikh Rashid Bin Saeed Road, P.O. Box 4090, Abu Dhabi, U.A.E.",
      officeLines: [
        "+971 2 4492700 (Chancery)",
        "+971 2 4447768 (Consular)",
        "+971 2 4447738 (Ambassador's Office)"
      ],
      emergencyPhone: "+971 50 8995583",
      email: "amb.abudhabi@mea.gov.in"
    },
    "united kingdom": {
      missionName: "British Embassy Abu Dhabi",
      address: "Al Hisn Street, Al Markaziyah West, PO Box 248, Abu Dhabi, United Arab Emirates",
      officeLines: [
        "+971 4 309 4444"
      ]
    },
    "united states": {
      missionName: "U.S. Embassy Abu Dhabi",
      address: "Embassies District, Plot 38, Sector W59-02, Street No. 4, Abu Dhabi, U.A.E.",
      officeLines: [
        "+971 2 414-2200"
      ],
      emergencyPhone: "+971 2 414-2200",
      email: "abudhabiacs@state.gov"
    },
    china: {
      missionName: "Embassy of the People's Republic of China in the United Arab Emirates",
      address: "Plot No. 26, Sector No. W-22, Abu Dhabi, P.O. Box 2741, Abu Dhabi, UAE",
      officeLines: [
        "+971-2-4434276"
      ],
      email: "chinaemb_ae@mfa.gov.cn",
      _source: "https://www.mfa.gov.cn/ara/wjb/zwjg_/828_/yz_/200302/t20030227_9601623.html (China MFA official site, Arabic-language archive page)",
      _note: "Fax numbers also published: +971-2-6440415 and +971-2-4436835. No separately labeled 24h emergency line found on this page; page is an older archival MFA page, current staffed numbers may have been updated since."
    },
    australia: {
      missionName: "Australian Embassy, United Arab Emirates",
      address: "Level 16, Nayel & Bin Harmal Tower, Zayed the First Street, Abu Dhabi, United Arab Emirates",
      officeLines: [
        "+971 2 401 7500"
      ],
      emergencyPhone: "+61 2 6261 3305"
    }
  },
  "saudi arabia": {
    malaysia: {
      missionName: "Embassy of Malaysia, Riyadh",
      address: "Diplomatic Quarter, P.O. Box 94335, 11693 Riyadh, Saudi Arabia",
      officeLines: [
        "+966 11 488 7098"
      ],
      email: "mwriyadh@kln.gov.my"
    },
    brunei: {
      missionName: "Embassy of Brunei Darussalam, Riyadh",
      address: "No. 6501, Saad Al Dousi Street, Al Mursalat District, Riyadh 12461, Kingdom of Saudi Arabia (P.O. Box 94314, Riyadh 11693)",
      officeLines: [
        "+966 11 456 0814",
        "+966 11 205 4911",
        "+966 55 526 2249 (hotline)"
      ],
      email: "riyadh.saudiarabia@mfa.gov.bn"
    },
    singapore: {
      missionName: "Embassy of the Republic of Singapore, Riyadh",
      address: "Diplomatic Quarter (DQ), near the 5th Roundabout off the DQ Main Entrance road, next to the Embassy of the United Arab Emirates, Riyadh, Saudi Arabia",
      emergencyPhone: "+966 50 019 1220 (urgent consular assistance)"
    },
    indonesia: {
      missionName: "Embassy of the Republic of Indonesia, Riyadh",
      address: "7669 Amr Aldamri St, Al Safarat, Riyadh 12512, Saudi Arabia",
      officeLines: [
        "+966 11 488 2800"
      ],
      emergencyPhone: "+62-812-9007-0027",
      email: "pelindunganwni@kemlu.go.id"
    },
    thailand: {
      missionName: "Royal Thai Embassy, Riyadh",
      address: "Diplomatic Quarter, P.O. Box 94359, Riyadh 11693, Saudi Arabia",
      officeLines: [
        "+966 11 230 9044",
        "+966 11 488-1174",
        "+966 11 488-0797",
        "+966 11 488-0300",
        "+966 11 488-1507"
      ],
      email: "thaiembassy.ruh@mfa.go.th"
    },
    philippines: {
      missionName: "Philippine Embassy, Riyadh",
      address: "Diplomatic Quarter, P.O. Box 94366, Riyadh 11693, Saudi Arabia",
      officeLines: [
        "+966-11-482-3559",
        "+966-11-482-0507",
        "+966-11-480-1918",
        "+966-11-482-3816"
      ],
      emergencyPhone: "+966-51-504-6375 (24/7 hotline); +966-56-989-3301 (Assistance-to-Nationals 24/7)",
      email: "riyadh.mis@dfa.gov.ph"
    },
    china: {
      missionName: "Embassy of the People's Republic of China, Riyadh",
      address: "Building No. 6654, Umro Adhamry Street, Al-Safarat, Riyadh, Kingdom of Saudi Arabia",
      officeLines: [
        "+966 11 483 2126"
      ],
      email: "chinaemb_sa@mfa.gov.cn"
    },
    japan: {
      missionName: "Embassy of Japan in Saudi Arabia",
      address: "A-11 Diplomatic Quarter, Riyadh, Saudi Arabia (P.O. Box 4095)",
      officeLines: [
        "(966-11) 488-1100"
      ]
    },
    india: {
      missionName: "Embassy of India, Riyadh",
      address: "B-1 Diplomatic Quarter, P.O. Box 94387, Riyadh 11693, Saudi Arabia",
      officeLines: [
        "+966 11 4884144",
        "+966 11 4884691",
        "+966 11 4884692"
      ],
      emergencyPhone: "+966 11 4884697 (24-hour helpline); Toll-free within Saudi Arabia: 800 247 1234",
      email: "cons.riyadh@mea.gov.in"
    },
    "united kingdom": {
      missionName: "British Embassy Riyadh",
      address: "PO Box 94351, Riyadh 11693, Saudi Arabia",
      officeLines: [
        "+966 (0)11 481 9100"
      ],
      emergencyPhone: "+44 (0)20 7008 5000"
    },
    "united states": {
      missionName: "U.S. Embassy Riyadh",
      address: "Abdullah Ibn Hudhafah As Sahmi Street, Roundabout No. 9, Diplomatic Quarter, Riyadh, Saudi Arabia",
      officeLines: [
        "+966-11-488-3800"
      ],
      emergencyPhone: "+966-11-488-3800",
      email: "RiyadhACS@state.gov"
    },
    australia: {
      missionName: "Australian Embassy, Saudi Arabia",
      address: "Abdullah Al-Sahmi Street, Diplomatic Quarter, PO Box 94400, Riyadh 11693, Saudi Arabia",
      officeLines: [
        "+966 11 250 0900"
      ],
      emergencyPhone: "+61 2 6261 3305"
    },
    "south korea": {
      missionName: "Consulate General of the Republic of Korea in Jeddah",
      address: "P.O. Box 55503, Jeddah 21544, Saudi Arabia",
      officeLines: [
        "+966-12-668-1990"
      ],
      email: "jeddah@mofa.go.kr"
    }
  },
  turkey: {
    malaysia: {
      missionName: "Consulate General of Malaysia, Istanbul",
      address: "Esentepe Mah. Ali Kaya Sok. No:1/1B, Polat Plaza, B Blok, Kat 8, Levent/Şişli, Istanbul, Turkey",
      officeLines: [
        "+90-212 989 10 01"
      ],
      emergencyPhone: "+90 531 716 05 51",
      email: "mwistanbul@kln.gov.my"
    },
    brunei: {
      missionName: "Embassy of Brunei Darussalam, Ankara",
      address: "Rafet Canitez Caddesi, Arif Nihat Asya Sokak No. 33, Oran, Çankaya, Ankara 06450, Republic of Türkiye",
      officeLines: [
        "+90 312 490 4460",
        "+90 312 490 4461",
        "+90 533 032 5454 (hotline)"
      ],
      email: "ankara.turkiye@mfa.gov.bn"
    },
    singapore: {
      missionName: "Embassy of the Republic of Singapore, Ankara",
      address: "719. Sokak No. 5, Yıldızevler Mahallesi, Çankaya, Ankara 06550, Turkey",
      officeLines: [
        "+90 312 442 4330"
      ]
    },
    indonesia: {
      missionName: "Embassy of the Republic of Indonesia, Ankara",
      address: "Abdullah Cevdet Sokak No. 10, Cankaya 06680, Ankara, Turkey (PO Box 42)",
      officeLines: [
        "(90-312) 438-2190/91"
      ],
      emergencyPhone: "+62-812-9007-0027",
      email: "pelindunganwni@kemlu.go.id"
    },
    thailand: {
      missionName: "Royal Thai Embassy, Ankara",
      address: "Koza Sokak No. 87, Gaziosmanpasa, 06700 Cankaya, Ankara, Turkey",
      officeLines: [
        "+90 312 437 4318",
        "+90 312 437 5248"
      ],
      email: "thaiembassy.ank@mfa.go.th"
    },
    philippines: {
      missionName: "Embassy of the Republic of the Philippines, Ankara",
      address: "Kazim Ozalp Mahallesi, Kumkapi Sokak No. 36, Cankaya 06700, Ankara, Turkey",
      officeLines: [
        "+90-312-442-3824",
        "+90-312-442-3827",
        "+90-312-442-3825"
      ],
      emergencyPhone: "+90-537-577-2344"
    },
    vietnam: {
      missionName: "Embassy of the Socialist Republic of Vietnam in Turkey",
      address: "414 Sokak No: 14, Birlik Mahallesi, 06610 Çankaya, Ankara, Turkey",
      officeLines: [
        "+90 312-446-8049"
      ],
      emergencyPhone: "+90 545-785-8548",
      email: "vnemb.tr@mofa.gov.vn"
    },
    japan: {
      missionName: "Embassy of Japan in Türkiye",
      address: "Resit Galip Caddesi No.81, Gaziosmanpasa, Ankara, Republic of Türkiye",
      officeLines: [
        "(90-312) 446-0500"
      ]
    },
    china: {
      missionName: "Embassy of the People's Republic of China in Türkiye",
      address: "Ferit Recai Ertuğrul Cad. No: 18, Oran, Ankara, Türkiye",
      officeLines: [
        "0090-312-4900660"
      ],
      email: "chinaemb_tr@mfa.gov.cn"
    },
    india: {
      missionName: "Embassy of India, Ankara",
      address: "77 Cinnah Caddesi, Cankaya 06680, Ankara, Türkiye",
      officeLines: [
        "+90 312 4382195",
        "+90 312 4382196",
        "+90 312 4382197",
        "+90 312 4382198"
      ],
      emergencyPhone: "+90 535 4904071",
      email: "hoc.ankara@mea.gov.in"
    },
    "united kingdom": {
      missionName: "British Embassy Ankara",
      address: "Şehit Ersan Caddesi 46/A, Çankaya, Ankara, Turkey",
      officeLines: [
        "+90 312 455 33 44"
      ]
    },
    "united states": {
      missionName: "U.S. Embassy Ankara",
      address: "110 Atatürk Blvd., Kavaklıdere, 06100 Ankara, Turkey",
      officeLines: [
        "+90-312-455-5555"
      ],
      emergencyPhone: "+90-312-455-5555"
    },
    australia: {
      missionName: "Australian Embassy, Türkiye",
      address: "MNG Building, Uğur Mumcu Caddesi No: 88, Level 7, Gaziosmanpaşa 06700, Ankara, Türkiye",
      officeLines: [
        "+90 312 459 9500"
      ],
      emergencyPhone: "+61 2 6261 3305"
    }
  },
  "south africa": {
    malaysia: {
      missionName: "High Commission of Malaysia, Pretoria",
      address: "1007 Francis Baard Street, Arcadia, Pretoria 0083, South Africa",
      officeLines: [
        "+27 (0)12 763 0900"
      ],
      email: "mwpretoria@kln.gov.my"
    },
    brunei: {
      missionName: "High Commission of Brunei Darussalam, Singapore (non-resident, concurrently accredited to South Africa)",
      address: "325 Tanglin Road, Singapore 247955",
      officeLines: [
        "+65 6733 9055",
        "+65 9673 0300 (hotline)"
      ],
      emergencyPhone: "+65 8134 2996",
      email: "singapore@mfa.gov.bn"
    },
    singapore: {
      missionName: "High Commission of the Republic of Singapore, Pretoria"
    },
    indonesia: {
      missionName: "Embassy of the Republic of Indonesia, Pretoria",
      address: "949 Schoeman Street, Hatfield, Pretoria 0082, South Africa",
      officeLines: [
        "+27 12 342 3350/1/2/3"
      ],
      emergencyPhone: "+62-812-9007-0027",
      email: "pelindunganwni@kemlu.go.id"
    },
    thailand: {
      missionName: "Royal Thai Embassy, Pretoria",
      address: "248 Pretorius/Hill Street, Arcadia, Pretoria 0083, South Africa",
      officeLines: [
        "+27 12 342-5470"
      ],
      email: "thaiembassy.pre@mfa.go.th"
    },
    philippines: {
      missionName: "Embassy of the Philippines, Pretoria",
      address: "54 Nicolson Street, Bailey's Muckleneuk, 0181 Pretoria, South Africa",
      officeLines: [
        "+27-12-346-0451",
        "+27-79-365-1854"
      ],
      emergencyPhone: "+27-72-437-9517 (Duty Officer); +27-82-556-9935 (Assistance to Filipino Nationals)"
    },
    vietnam: {
      missionName: "Embassy of the Socialist Republic of Vietnam in South Africa",
      address: "87 Brooks Street, Brooklyn, Pretoria, South Africa",
      officeLines: [
        "+27 12-362-8119",
        "+27 12-362-8118"
      ],
      emergencyPhone: "+27 62-230-7763",
      email: "embassy@vietnam.co.za"
    },
    japan: {
      missionName: "Embassy of Japan in the Republic of South Africa",
      address: "259 Baines Street, corner Frans Oerder Street, Groenkloof, Pretoria 0181, South Africa (Private Bag X999, Pretoria, 0001)",
      officeLines: [
        "(27-12) 452-1500"
      ]
    },
    china: {
      missionName: "Chinese Consulate General in Cape Town",
      address: "25 Rhodes Ave, Newlands, Cape Town; P.O. Box 23301, Claremont, 7735, South Africa",
      officeLines: [
        "0027-21-6740597"
      ],
      email: "capetown@csm.mfa.gov.cn"
    },
    india: {
      missionName: "High Commission of India, Pretoria",
      address: "852 Francis Baard Street, Arcadia 0083, Pretoria, South Africa",
      officeLines: [
        "+27 12 342 5392",
        "+27 12 342 5393",
        "+27 12 342 5394",
        "+27 12 342 5395"
      ],
      emergencyPhone: "+27 72 750 9167",
      email: "hc.pretoria@mea.gov.in"
    },
    "united kingdom": {
      missionName: "British High Commission Pretoria",
      address: "255 Hill Street, Arcadia, Pretoria, Gauteng 0083, South Africa",
      officeLines: [
        "+27 (0)12 421 7500"
      ],
      emergencyPhone: "+44 (0)20 7008 5000"
    },
    "united states": {
      missionName: "U.S. Consulate General Johannesburg",
      address: "1 Sandton Drive (opposite Sandton City Mall), Johannesburg 2196, South Africa",
      officeLines: [
        "+27-11-290-3000"
      ],
      emergencyPhone: "+27-79-111-1684",
      email: "consularjohannesburg@state.gov"
    },
    australia: {
      missionName: "Australian High Commission, South Africa",
      address: "292 Orient Street, Arcadia, Pretoria 0083, South Africa",
      officeLines: [
        "+27 12 423 6000"
      ],
      emergencyPhone: "+61 2 6261 3305",
      email: "consular.pretoria@dfat.gov.au"
    },
    "south korea": {
      missionName: "Embassy of the Republic of Korea to the Republic of South Africa",
      officeLines: [
        "+27-12-460-2508"
      ],
      emergencyPhone: "+27-66-332-5897"
    }
  },
  brazil: {
    malaysia: {
      missionName: "Embassy of Malaysia, Brasília",
      address: "SHIS QI 05, Chácara 62, Lago Sul, CEP 71615-904, Brasília-DF, Brazil",
      officeLines: [
        "+55 61 3248 5008"
      ],
      email: "mwbrasilia@kln.gov.my"
    },
    brunei: {
      missionName: "High Commission of Brunei Darussalam, Ottawa (non-resident, concurrently accredited to Brazil)",
      address: "395 Laurier Avenue East, Ottawa, Ontario K1N 6R4, Canada",
      officeLines: [
        "+1 613 234 5656",
        "+1 613 234 4275",
        "+1 613 864 5654 (hotline)"
      ],
      email: "ottawa.canada@mfa.gov.bn"
    },
    singapore: {
      missionName: "Embassy of the Republic of Singapore, Brasilia",
      address: "SHIS QL 24, Conjunto 3, Casa 11, Lago Sul, Brasília, Federal District, CEP 71665-035, Brazil",
      officeLines: [
        "+55 61 2191 6565"
      ],
      emergencyPhone: "+55 61 99584 9583 (after office hours, consular assistance)",
      email: "singemb_bsb@mfa.sg"
    },
    indonesia: {
      missionName: "Embassy of the Republic of Indonesia, Brasília",
      address: "SES Avenida das Nações, Quadra 805, Lote 20, Asa Sul, Brasília-DF, Brazil",
      officeLines: [
        "+55 61 3443 8800",
        "+55 61 3443 1788"
      ],
      emergencyPhone: "+62-812-9007-0027",
      email: "pelindunganwni@kemlu.go.id"
    },
    thailand: {
      missionName: "Royal Thai Embassy, Brasília",
      address: "SEN, Avenida das Nações, Lote 10, 70800-912 Brasília, DF, Brazil",
      officeLines: [
        "+55 61 3224-6943"
      ],
      email: "thaiembassy.bra@mfa.go.th"
    },
    philippines: {
      missionName: "Embassy of the Republic of the Philippines, Brasilia",
      address: "SEN 801 - Asa Norte, Brasilia, DF, CEP 70800-910, Brazil",
      officeLines: [
        "+55-61-3224-8694",
        "+55-61-3321-9476"
      ],
      emergencyPhone: "+55-61-9-9389-3042"
    },
    japan: {
      missionName: "Embassy of Japan in Brazil",
      address: "SES Avenida das Nações, Quadra 811, Lote 39, 70425-900, Brasília, D.F., Brazil",
      officeLines: [
        "(55-61) 3442-4200"
      ]
    },
    china: {
      missionName: "Chinese Consulate General in Rio de Janeiro",
      address: "Rua Muniz Barreto, 715, Botafogo, RJ, Brasil, CEP 22251-090",
      officeLines: [
        "0055-21-34392998"
      ],
      email: "chinaconsul_rj_br@mfa.gov.cn"
    },
    india: {
      missionName: "Embassy of India, Brasilia",
      address: "SES, Quadra 805, Lote 24, Asa Sul, Brasília, DF, CEP 70452-901, Brazil",
      officeLines: [
        "+55 61 3364 1273"
      ],
      emergencyPhone: "+55 61 98139 1127",
      email: "cons.brasilia@mea.gov.in"
    },
    "united kingdom": {
      missionName: "British Embassy Brasilia",
      address: "Quadra 801, Conjunto K, Lote 08, Av. das Nações, Asa Sul, 70408-900 Brasilia, Brazil",
      officeLines: [
        "+55 (61) 3329 2300"
      ],
      emergencyPhone: "+44 (0)20 7008 5000"
    },
    "united states": {
      missionName: "U.S. Embassy Brasilia",
      address: "SES 801 - Avenida das Nacoes, Lote 3, 70403-900, Brasília, DF, Brazil",
      officeLines: [
        "+55 61 3312-7000"
      ],
      emergencyPhone: "+55 61 3312-7400",
      email: "BrasiliaACS@state.gov"
    },
    australia: {
      missionName: "Australian Embassy, Brazil",
      address: "SES 801 Conjunto K Lote 7, Asa Sul, Brasília - DF, 70200-010, Brazil",
      officeLines: [
        "+55 61 3226 3111"
      ],
      emergencyPhone: "+61 2 6261 3305"
    }
  },
  mexico: {
    malaysia: {
      missionName: "Embassy of Malaysia, Mexico City",
      address: "Monte Líbano 1015, Lomas de Chapultepec VIII Secc, Miguel Hidalgo, 11000 Ciudad de México, Mexico",
      officeLines: [
        "+52 55 5282 4656"
      ],
      email: "mwmexico@kln.gov.my"
    },
    brunei: {
      missionName: "Embassy of Brunei Darussalam, Washington D.C. (non-resident, concurrently accredited to Mexico)",
      address: "3520 International Court NW, Washington D.C. 20008, United States of America",
      officeLines: [
        "+1 202 237 1838",
        "+1 202 725 5366 (hotline)"
      ],
      email: "washington.usa@mfa.gov.bn"
    },
    singapore: {
      missionName: "Honorary Consulate of the Republic of Singapore, Mexico City"
    },
    indonesia: {
      missionName: "Embassy of the Republic of Indonesia, Mexico City",
      address: "Julio Verne No. 27, Colonia Polanco, Delegación Miguel Hidalgo, C.P. 11560, Mexico City, Mexico",
      officeLines: [
        "(52-55) 5280-5748",
        "(52-55) 5280-6363",
        "(52-55) 5280-6863",
        "(52-55) 5280-3440"
      ],
      emergencyPhone: "+62-812-9007-0027",
      email: "pelindunganwni@kemlu.go.id"
    },
    thailand: {
      missionName: "Royal Thai Embassy, Mexico City",
      address: "Alpes 365, Lomas de Chapultepec, Miguel Hidalgo, 11000 Mexico City, Mexico",
      officeLines: [
        "+52 55 5540-4551",
        "+52 55 5540-4529",
        "+52 55 5540-4711",
        "+52 55 5540-4674"
      ],
      email: "thaiembassy.mex@mfa.go.th"
    },
    philippines: {
      missionName: "Philippine Embassy, Mexico City",
      address: "Avenida Thiers 111 (corner Cuvier 55), Colonia Anzures, Delegacion Miguel Hidalgo, Ciudad de Mexico, C.P. 11590, Mexico",
      officeLines: [],
      emergencyPhone: "+52-55-2771-3776 (urgent cases outside office hours, weekends, holidays)"
    },
    vietnam: {
      missionName: "Embassy of the Socialist Republic of Vietnam in Mexico",
      address: "Sierra Ventana No. 255, Col. Lomas de Chapultepec, Del. Miguel Hidalgo, CP 11000, Mexico City, Mexico",
      officeLines: [
        "+52 55-5540-1632"
      ]
    },
    japan: {
      missionName: "Embassy of Japan in Mexico",
      address: "Paseo de la Reforma No. 243, Torre Mapfre, Piso 9, Col. Cuauhtémoc, C.P. 06500, Ciudad de México, Mexico",
      officeLines: [
        "(52-55) 5211-0028"
      ]
    },
    india: {
      missionName: "Embassy of India, Mexico City",
      address: "Musset 325, Colonia Polanco, Mexico City, C.P. 11550, Mexico",
      officeLines: [
        "+52 55 5531 1050",
        "+52 55 5531 1002"
      ],
      emergencyPhone: "+52 1 55 5548 7539",
      email: "dcm.mexico@mea.gov.in"
    },
    "united kingdom": {
      missionName: "British Embassy Mexico City",
      address: "Torre del Ángel, Paseo de la Reforma 350, Col. Juárez, 06600 Mexico City, Mexico",
      officeLines: [
        "+52 (55) 1670 3200"
      ],
      emergencyPhone: "+44 (0)20 7008 5000"
    },
    china: {
      missionName: "Embassy of the People's Republic of China in the United Mexican States",
      address: "Av. San Jerónimo 217B, Tizapán San Ángel, La Otra Banda, Álvaro Obregón, 01090 Ciudad de México, CDMX, Mexico",
      officeLines: [
        "+52-55-56160609"
      ],
      email: "chinaemb_mx@mfa.gov.cn",
      _source: "https://www.mfa.gov.cn/ara/wjb/zwjg_/828_/bmz/200302/t20030227_9601740.html (China MFA official site, Arabic-language archive page)",
      _note: "Fax also published: +52-55-56160460. No separately labeled 24h emergency line found on this page; page is an older archival MFA page, current staffed numbers may have been updated since."
    },
    "united states": {
      missionName: "U.S. Embassy Mexico City",
      address: "Paseo de la Reforma 305, Colonia Cuauhtémoc, 06500 Mexico City, Mexico",
      officeLines: [
        "011-52-55-5080-2000"
      ],
      emergencyPhone: "01-55-5080-2000, ext. 0",
      email: "acsmexicocity@state.gov"
    },
    australia: {
      missionName: "Australian Embassy, Mexico",
      address: "Rubén Darío 55, Col. Bosque de Chapultepec, Miguel Hidalgo, 11560 Mexico City, Mexico",
      officeLines: [
        "+52 55 1101 2200"
      ],
      emergencyPhone: "+61 2 6261 3305",
      email: "australian.embassy.mexico@dfat.gov.au"
    }
  }
};

// The nationality choices already offered elsewhere in the app (flight/
// insurance Traveller Details — see nationalityOptions in
// lib/controllers/insurance_controller.dart) and in Account Setting's
// Country/Region picker, reused here as suggestions when adding an
// embassy so the admin's spelling matches what a user's own
// users/{uid}.country value will actually be.
export const COMMON_HOME_COUNTRIES = [
  "Malaysia",
  "Singapore",
  "Indonesia",
  "Thailand",
  "Philippines",
  "Vietnam",
  "Brunei",
  "China",
  "Japan",
  "South Korea",
  "India",
  "United Kingdom",
  "United States",
  "Australia"
];

export function titleCase(key) {
  return String(key || "").replace(/\b\w/g, (c) => c.toUpperCase());
}
