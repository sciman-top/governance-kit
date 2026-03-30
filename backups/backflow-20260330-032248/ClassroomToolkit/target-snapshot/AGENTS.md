# AGENTS.md 鈥?ClassroomToolkit 椤圭洰瑙勫垯锛圕odex锛?**椤圭洰**: ClassroomToolkit  
**绫诲瀷**: Windows WPF (.NET 10)  
**閫傜敤鑼冨洿**: 椤圭洰绾э紙浠撳簱鏍癸級  
**鐗堟湰**: 3.73  
**鏈€鍚庢洿鏂?*: 2026-03-30

## 1. 闃呰鎸囧紩锛堥」鐩骇锛?- 鏈枃浠舵壙鎺?`GlobalUser/AGENTS.md`锛屼粎瀹氫箟鏈粨钀藉湴鍔ㄤ綔锛圵HERE/HOW锛夈€?- 鍥哄畾缁撴瀯锛歚1 / A / B / C / D`銆?- 瑁佸喅閾撅細`杩愯浜嬪疄/浠ｇ爜 > 椤圭洰绾ф枃浠?> 鍏ㄥ眬鏂囦欢 > 涓存椂涓婁笅鏂嘸銆?
## A. 椤圭洰鍏辨€у熀绾匡紙浠呮湰浠擄級
### A.1 椤圭洰涓嶅彉绾︽潫
- 璇惧爞鍙敤鎬т紭鍏堬細涓嶅彲宕╂簝銆佷笉鍙暱鏃堕棿鍗℃锛涘閮ㄤ緷璧栧け璐ュ繀椤诲彲闄嶇骇銆?- Interop 闃插尽锛歐in32/COM 寮傚父涓嶅緱鍐掓场鍒?UI锛屽繀椤诲湪杈圭晫灞傛嫤鎴€?- 鍏煎淇濇姢锛氫笉寰楃牬鍧?`students.xlsx`銆乣student_photos/`銆乣settings.ini`銆?
### A.2 椤圭洰鎵ц閿氱偣
1. 姣忔鏀瑰姩鍏堝０鏄庯細`杈圭晫 -> 褰撳墠钀界偣 -> 鐩爣褰掑 -> 杩佺Щ鎵规`銆?2. 灏忔闂幆锛屼紭鍏堟牴鍥犱慨澶嶏紱姝㈣琛ヤ竵蹇呴』缁欏嚭鍥炴敹鏃剁偣銆?3. 姣忔鍙樻洿鐣欏瓨锛歚渚濇嵁 -> 鍛戒护 -> 璇佹嵁 -> 鍥炴粴`銆?
### A.3 N/A policy
- minimum fields: reason, alternative_verification, evidence_link.

## B. Codex 骞冲彴宸紓锛堥」鐩唴锛?### B.1 鍔犺浇涓庤瘖鏂?- 浼樺厛绾э細`AGENTS.override.md > AGENTS.md > fallback`銆?- 鏈€灏忚瘖鏂細`codex status -> codex --version -> codex --help`銆?- `override` 浠呯敤浜庣煭鏈熸帓闅滐紱缁撹鍚庡繀椤绘竻鐞嗗苟澶嶆祴銆?
### B.2 骞冲彴寮傚父鍥為€€
- 鍛戒护涓嶅彲鐢ㄦ垨琛屼负涓嶄竴鑷存椂锛岃褰曪細`N/A`銆佸師鍥犮€佹浛浠ｅ懡浠ゃ€佽瘉鎹綅缃€?
## C. 椤圭洰宸紓锛堥鍩熶笌鎶€鏈級
### C.1 妯″潡杈圭晫涓庡綊瀹?- `src/ClassroomToolkit.App`锛歐PF UI銆丮ainViewModel銆佸惎鍔?DI銆?- `src/ClassroomToolkit.Application`锛氬簲鐢ㄧ敤渚嬬紪鎺掋€佽法妯″潡娴佺▼鍗忚皟銆?- `src/ClassroomToolkit.Domain`锛氭牳蹇冧笟鍔¤鍒欍€?- `src/ClassroomToolkit.Services`锛氭ˉ鎺ヤ笌缂栨帓锛屼笉鎵挎帴鏍稿績涓氬姟瑙勫垯銆?- `src/ClassroomToolkit.Interop`锛歐in32/COM/WPS/UIAutomation 楂橀闄╁皝瑁呫€?- `src/ClassroomToolkit.Infra`锛氶厤缃€佹寔涔呭寲銆佹枃浠剁郴缁熴€?- `src/ClassroomToolkit.App/Windowing`锛氬绐楀彛缂栨帓銆?- `tests/ClassroomToolkit.Tests`锛歺Unit + FluentAssertions銆?
### C.2 Gate commands and execution order
- dotnet build ClassroomToolkit.sln -c Debug
- dotnet test tests/ClassroomToolkit.Tests/ClassroomToolkit.Tests.csproj -c Debug
- dotnet test tests/ClassroomToolkit.Tests/ClassroomToolkit.Tests.csproj -c Debug --filter "FullyQualifiedName~ArchitectureDependencyTests|FullyQualifiedName~Contract|FullyQualifiedName~Invariant"
- N/A (scripts/quality/check-hotspot-line-budgets.ps1 not found)
- quick gate: N/A (scripts/quality/run-local-quality-gates.ps1 not found)
- fixed order: build -> test -> contract/invariant -> hotspot.

### C.3 Command presence and N/A fallback verification
- precheck: Get-Command dotnet, Test-Path tests/ClassroomToolkit.Tests/ClassroomToolkit.Tests.csproj, N/A (hotspot script missing).
- if hotspot is missing: mark hotspot=N/A, run contract/invariant subset and record manual hotspot review.
- if contract/invariant subset is unavailable: mark contract/invariant=N/A, run full dotnet test and record contract-gap risks.
- any N/A must preserve semantic order: build -> test -> contract/invariant -> hotspot.

### C.4 澶辫触鍒嗘祦涓庨樆鏂?- `build` 澶辫触锛氬厛淇紪璇戦敊璇€?- `test` 澶辫触锛氬厛淇洖褰掓垨鐢ㄤ緥銆?- `contract/invariant` 澶辫触锛氶珮椋庨櫓闃绘柇锛岀姝㈠悎骞躲€?- `hotspot` 瓒呴绠楋細鎷嗗垎鎴栬縼绉荤儹鐐归€昏緫鍚庡妫€銆?
### C.5 璇佹嵁涓庡洖婊?- 璇佹嵁鐩綍锛歚docs/change-evidence/`锛堜笉瀛樺湪鍒欓娆″垱寤猴級銆?- 寤鸿鍛藉悕锛歚docs/change-evidence/YYYYMMDD-<topic>.md`銆?- 鐣欑棔妯℃澘锛歚瑙勫垯ID=锛涘奖鍝嶆ā鍧?锛涘綋鍓嶈惤鐐?锛涚洰鏍囧綊瀹?锛涜縼绉绘壒娆?锛涢闄╃瓑绾?锛涙墽琛屽懡浠?锛涢獙璇佽瘉鎹?锛涘洖婊氬姩浣?`銆?- 鏈€浣庡瓧娈碉細`瑙勫垯ID`銆乣椋庨櫓绛夌骇`銆乣鎵ц鍛戒护`銆乣楠岃瘉璇佹嵁`銆乣鍥炴粴鍔ㄤ綔`銆?- Waiver 閿細`owner`銆乣expires_at`銆乣status`銆乣recovery_plan`銆乣evidence_link`銆?
### C.6 鎵挎帴鏄犲皠锛圙lobal -> Repo锛?- `R1`锛欰.2 钀界偣澹版槑 + C.1 妯″潡杈圭晫銆?- `R2/R3`锛欰.2 灏忔闂幆涓庢牴鍥犱紭鍏堛€?- `R4/R6`锛欳.2 闂ㄧ閾捐矾 + C.3 鍛戒护瀛樺湪鎬т笌 N/A 鏇夸唬 + C.4 澶辫触闃绘柇銆?- `R7`锛欰.1 鍏煎淇濇姢銆?- `R8/E3`锛欳.5 璇佹嵁涓?Waiver銆?- `E1/E2`锛氭枃妗ｇ増鏈寲 + `observe -> enforce` 鍒囨崲鐣欑棔銆?- `E4/E5/E6`锛氭寚鏍囪仈鍔ㄣ€佷緵搴旈摼闂ㄧ銆佹暟鎹粨鏋勮縼绉诲洖婊氥€?
### C.7 鐩爣浠撶洿鏀瑰洖鐏岀瓥鐣?- 瑙勫垯婧愬綊瀹匡細`E:/CODE/governance-kit/source/project/ClassroomToolkit/*`銆?- 鍏佽鍦ㄧ洰鏍囦粨涓存椂鐩存敼鐢ㄤ簬蹇€熻瘯閿欙紝浣嗗繀椤诲湪鍚屼竴宸ヤ綔鏃ュ洖鐏屽埌瑙勫垯婧愬苟鐣欑棔銆?- 鍥炵亴鍚庢墽琛岋細`powershell -File E:/CODE/governance-kit/scripts/install.ps1 -Mode safe`锛岀‘淇?`source` 涓?`target` 鍐嶆涓€鑷淬€?- 鏈洖鐏屽墠锛岀姝㈠啀娆℃墽琛?`sync/install` 浠ュ厤瑕嗙洊鏈矇娣€鏀瑰姩銆?## D. 缁存姢鏍￠獙娓呭崟锛堥」鐩骇锛?- 浠呰惤鍦版湰浠撲簨瀹烇紝涓嶅鍐欏叏灞€瑙勫垯姝ｆ枃銆?- 涓?`GlobalUser/AGENTS.md` 鑱岃矗浜掕ˉ锛屼笉閲嶅彔銆佷笉缂哄け銆?- 鍗忓悓閾惧畬鏁达細`瑙勫垯 -> 钀界偣 -> 鍛戒护 -> 璇佹嵁 -> 鍥炴粴`銆?
- 鐩爣浠撶洿鏀瑰悗蹇呴』瀹屾垚瑙勫垯婧愬洖鐏屼笌鍐嶅垎鍙戞牎楠屻€?- 瑙勫垯鍗囩骇鍚庡悓姝ユ牎楠屾壙鎺ユ槧灏勪笌璇佹嵁妯℃澘涓€鑷存€с€?




