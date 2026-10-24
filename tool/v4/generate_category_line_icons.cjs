// Offline generation from the same ISC-licensed Lucide source used by the HTML.
const fs=require('fs'),path=require('path');
const root=path.resolve(__dirname,'../..'),icons=require(path.join(root,'docs/design/card-refresh/prototype/vendor/lucide.min.js')).icons;
const source=fs.readFileSync(path.join(root,'lib/services/data/category_service.dart'),'utf8').split('static IconData getCategoryIcon(')[1];
const names=[...source.matchAll(/case '([^']+)':/g)].map(m=>m[1]);
const aliases={
 category:'Shapes',label:'Tag',favorite:'Heart',local_dining:'Utensils',restaurant:'Utensils',fastfood:'Sandwich',local_cafe:'Coffee',local_bar:'Wine',local_pizza:'Pizza',cake:'CakeSlice',breakfast_dining:'Coffee',lunch_dining:'Utensils',dinner_dining:'Soup',icecream:'IceCreamBowl',bakery_dining:'Croissant',liquor:'Wine',wine_bar:'Wine',restaurant_menu:'Utensils',set_meal:'Fish',ramen_dining:'Soup',delivery_dining:'Bike',
 directions_car:'Car',directions_bus:'Bus',directions_subway:'TrainFront',local_taxi:'CarTaxiFront',flight:'Plane',train:'TrainFront',motorcycle:'Bike',directions_bike:'Bike',directions_walk:'Footprints',boat:'Ship',electric_scooter:'Bike',local_gas_station:'Fuel',local_parking:'SquareParking',local_shipping:'Truck',traffic:'TrafficCone',directions_railway:'TrainFront',airport_shuttle:'BusFront',pedal_bike:'Bike',car_rental:'CarFront',
 shopping_cart:'ShoppingCart',local_mall:'ShoppingBag',local_grocery_store:'ShoppingBasket',storefront:'Store',local_offer:'Tag',receipt:'ReceiptText',sell:'Tag',price_check:'BadgeDollarSign',card_giftcard:'Gift',redeem:'Gift',inventory:'Package',add_shopping_cart:'ShoppingCart',loyalty:'BadgePercent',
 home:'House',family_restroom:'UsersRound',apartment:'Building2',cleaning_services:'BrushCleaning',plumbing:'Wrench',electrical_services:'PlugZap',flash_on:'Zap',water_drop:'Droplet',air:'Wind',kitchen:'Refrigerator',bathtub:'Bath',bed:'BedDouble',chair:'Armchair',table_restaurant:'Table',hvac:'AirVent',roofing:'House',foundation:'BrickWall',home_work:'Building2',home_repair_service:'Wrench',
 phone_android:'Smartphone',phone_iphone:'Smartphone',tablet:'Tablet',computer:'Monitor',desktop_windows:'Monitor',headset:'Headset',
 movie:'Clapperboard',music_note:'Music',sports_esports:'Gamepad2',theater_comedy:'Drama',casino:'Dices',celebration:'PartyPopper',party_mode:'PartyPopper',nightlife:'Martini',local_activity:'Ticket',attractions:'FerrisWheel',beach_access:'Umbrella',pool:'Waves',spa:'Flower2',games:'Gamepad2',sports:'Trophy',sports_soccer:'Goal',sports_basketball:'CircleDot',sports_tennis:'CircleDot',group:'Users',
 local_hospital:'Hospital',medical_services:'HeartPulse',local_pharmacy:'Pill',health_and_safety:'ShieldPlus',medication:'Pill',fitness_center:'Dumbbell',self_improvement:'PersonStanding',psychology:'Brain',healing:'Bandage',monitor_heart:'HeartPulse',elderly:'PersonStanding',accessible:'Accessibility',medical_information:'ClipboardPlus',biotech:'Microscope',coronavirus:'Biohazard',vaccines:'Syringe',child_care:'Baby',
 school:'GraduationCap',book:'BookOpen',library_books:'LibraryBig',menu_book:'BookOpen',auto_stories:'BookOpenText',edit:'Pencil',create:'PencilLine',calculate:'Calculator',science:'FlaskConical',music_video:'Music',translate:'Languages',language:'Globe',quiz:'CircleHelp',
 pets:'PawPrint',cruelty_free:'Rabbit',bug_report:'Bug',emoji_nature:'Flower',park:'TreeDeciduous',grass:'Sprout',forest:'Trees',agriculture:'Tractor',eco:'Leaf',local_florist:'Flower2',yard:'Flower',
 checkroom:'Shirt',face:'Smile',face_retouching:'Sparkles',content_cut:'Scissors',dry_cleaning:'Shirt',local_laundry_service:'WashingMachine',iron:'Shirt',watch_later:'Clock',ring_volume:'PhoneCall',gesture:'Hand',
 work:'BriefcaseBusiness',work_outline:'BriefcaseBusiness',business:'Building2',business_center:'BriefcaseBusiness',engineering:'HardHat',design_services:'PencilRuler',construction:'Hammer',handyman:'Wrench',developer_mode:'CodeXml',gavel:'Gavel',balance:'Scale',support_agent:'Headset',
 account_balance:'Landmark',account_balance_wallet:'Wallet',savings:'PiggyBank',show_chart:'ChartNoAxesCombined',analytics:'ChartColumn',paid:'BadgeDollarSign',money:'Banknote',currency_exchange:'Coins',payment:'CreditCard',receipt_long:'ReceiptText',request_quote:'FileText',monetization_on:'CircleDollarSign',price_change:'BadgeDollarSign',euro:'Euro',yen:'JapaneseYen',
 emoji_events:'Trophy',volunteer_activism:'HandHeart',military_tech:'Medal',workspace_premium:'Award',verified:'BadgeCheck',auto_awesome:'Sparkles',new_releases:'BadgeAlert',toll:'Coins',confirmation_number:'Ticket',real_estate_agent:'House',energy_savings_leaf:'Leaf',solar_power:'Sun',oil_barrel:'Cylinder',electric_bolt:'Zap',
 schedule:'Clock',undo:'Undo2',refresh:'RefreshCw',autorenew:'RotateCw',update:'History',sync:'RefreshCw',published_with_changes:'RefreshCw',swap_horiz:'ArrowLeftRight',compare_arrows:'ArrowLeftRight',call_received:'ArrowDownLeft',input:'LogIn',move_down:'ArrowDown',south:'ArrowDown',call_made:'ArrowUpRight',
 camera_alt:'Camera',photo_camera:'Camera',videocam:'Video',print:'Printer',local_post_office:'Mail',public:'Globe',place:'MapPin',location_on:'MapPin',explore:'Compass',access_time:'Clock',security:'ShieldCheck',subway:'TrainFront',directions_transit:'TrainFront',groups:'Users',network_cell:'Signal',devices_other:'MonitorSmartphone',card_travel:'BriefcaseBusiness',hotel:'BedDouble',child_friendly:'Baby',alt_route:'Route',build:'Wrench',
 // Additional identifiers already stored by previous versions or imports.
 restaurant_menu:'Utensils',food_bank:'Utensils',free_breakfast:'Coffee',house:'House',theaters:'Clapperboard',more_horiz:'Ellipsis',payments:'Banknote',attach_money:'Banknote'
};
const mapped={};
for(const key of [...new Set([...names,...Object.keys(aliases)])]){
 const name=aliases[key]||key.split('_').map(x=>x[0].toUpperCase()+x.slice(1)).join('');
 if(!icons[name])throw Error('Missing Lucide alias: '+key+' -> '+name);
 mapped[key]=name;
}
const esc=s=>String(s).replaceAll('&','&amp;').replaceAll('"','&quot;');
for(const name of new Set([...Object.values(mapped),'Trash2','ImageOff','ArrowRight','ListFilter','Layers','GitMerge','Archive','FileCode2','Network','ListX','FolderMinus','CloudDownload','Images','Mic','Repeat2','Bell'])){
 const children=icons[name].map(([tag,attrs])=>`<${tag} ${Object.entries(attrs).map(([k,v])=>`${k}="${esc(v)}"`).join(' ')}/>`).join('');
 const svg=`<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="#262829" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">${children}</svg>\n`;
 fs.writeFileSync(path.join(root,'packages/beecount_ui/assets/icons',name+'.svg'),svg);
}
const dart='// Generated by tool/v4/generate_category_line_icons.cjs.\n// Saved identifiers retain their meaning; custom image resolution stays separate.\nconst categoryLineIconNames = <String, String>{\n'+Object.entries(mapped).sort(([a],[b])=>a.localeCompare(b)).map(([k,v])=>`  '${k}': '${v}',`).join('\n')+'\n};\n';
fs.writeFileSync(path.join(root,'lib/presentation/v4/bindings/category_line_icon_names.dart'),dart);
console.log(JSON.stringify({legacyIdentifiers:names.length,mappedIdentifiers:Object.keys(mapped).length,lineIcons:new Set(Object.values(mapped)).size}));
