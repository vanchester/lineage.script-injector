Script Injector v0.1beta

О ПРОГРАММЕ.
	Программа предназначена для переноса скриптов из подготовленных файлов в рабочие версии.
	
ПРИНЦИП РАБОТЫ
	После запуска инжектор сканирует файлы в папке, указанной в ini-файле в параметре NewScriptPath, либо в своей рабочей 
	директории и проверяет их наличие в папке рабочих скриптов (указывается в ini-файле в параметре WorkScriptPath).
	Если файлы в папке с рабочими скриптами отсутствуют, то просто копирует их в нее (кроме *.obj файлов).
	Если файл с таким же именем (кроме *.obj) уже присутствует в папке с рабочими скриптами, то пытается распознать его и 
	перенести в него данные согласно структуре файла и указанным параметрам работы. Перед внесением изменений в файл, инжектор
	создает резервную копию этого файла с расширением bak.
	Со всех *.obj файлов считываются классы AI и вставляются в рабочий файл ai.obj.
	
ПАРАМЕТРЫ РАБОТЫ
	Все скрипты в программе условно делятся на 
	- 	линейные, в которых рабочая единица (итем, скилл и т.п.) описывается в одну строку
		и ограничивается с обеих сторон словами unit_begin и unit_end, где unit может принимать любые значения.
		Примером линейных скриптов могут быть areadata.txt, itemdata.txt и др. В линейных скриптах, как правило, позиция единицы
		по отношению к другим единицам не оказывает никакого влияния, связей между единицами нет.
	-	нелинейные, в которых данные единицы идут в несколько строк, образуя блок данных (ai.obj, multisell.txt, skillacquire.txt 
		и т.д.). В таких скриптах позиция единицы выбирается исходя из ее связей с другими единицами.
	
	В связи с этим параметры для этих двух типов различаются друг от друга.
	
	Настройки работы инжектора устанавливаются в импортируемых данных с помощью директив.
	Общий вид директивы
	{$X Y}
	где X - параметр, Y - его значение.
	X может быть:
		W - задает тип вставки данных (Work type):
			0 - "простая" вставка данных. Данные вставляются в рабочий файл "как есть" (для нелинейных - полная замена блока).
			1 - "универсальная" вставка данных:
				  Для линейных - недостающие параметры берутся из существующей единицы.
				  Для нелинейных - вставка данных в блок с сохранением уже существующих в нем позиций (кроме дублирующихся).
			2 - вставка данных отключена. Используется для комментирования/удаления единиц в рабочем скрипте.
		C - задает тип комментирования (Comment type):
			0 - если уже имеется единица с ID или именем, равным соответственно ID или имени вставляемой единицы, уже присутствует 
			в рабочих скриптах она будет закомментирована символом '//'.
			1 - дублирующаяся строка будет удалена.
		P - задает позицию вставки (Position type)
			0 - данные будут вставлены в конец файла (для нелинейных - в конец блока).
			1 - вставка данных в текущую позицию (если такая единица уже имеется) (для нелинейных - в начало блока)
	Значения по умолчанию:
	Параметр	|	Линейные	|	Нелинейные
		W		|		0		|		1
		С		|		1		|		1*
		P		|		0		|		1
	-
	 * для obj-файлов параметр врегда равен 0
	
	При работе с классами AI в режиме {$P 0} анализируются зависимости между классами. Инжектор по возможности оставляет их неизменными,
	вписывая на месте существующего класса пустой класс с параметрами с тем же именем и добавляет новый в конец файла.
	
	Директивы могут быть указаны в любом месте комментария вставляемых данных (для нелинейных скриптов - до начала блока). Указанное 
	значение распространяется на все строки, расположенные ниже него и может быть отменено повторным добавлением этого же параметра 
	с противоположным значением ниже по тексту.
	
	С помощью комбинации параметров можно решить практически любую задачу вставки данных.

ДОПОЛНИТЕЛЬНО
	- кодировка "входных" файлов не имеет значения при вставке данных в соответствующие рабочие файлы
	- для multisell.txt исправляются ошибки с символом ';' в позициях мультиселла
	- начиная с версии 0.2b инжектор работает с html файлами. Он сканирует в указанной в параметре NewScriptPath (если не указана, то 
	  в своей рабочей папке) директории html*, и, если находит их в и NewScriptPath, и в WorkScriptPath\..\, копирует их содержимое в соответствующую
	  папку с сохранением структуры файлов и папок
	
ПРИМЕРЫ

Линейные файлы:

Импортируемый файл:
-- file begin --
//fortress npc {$W 0} {$C 0} {$P 1}
npc_begin	citizen	32468	[clear_npc]		npc_ai={[default_npc]}	npc_end
//iop race {$W 1} {$C 1} {$P 0}
npc_begin	citizen	32349	[rignos]		npc_ai={[rignos]}	undying=1	npc_end
--- file end ---

Рабочий файл ДО работы инжектора
-- file begin --
<...>
npc_begin	citizen	32468	[clear_npc_32468]	level=70	acquire_exp_rate=0	acquire_sp=0	unsowing=1	clan={}	ignore_clan_list={}	clan_help_range=0	slot_chest=[]	slot_rhand=[]	slot_lhand=[]	shield_defense_rate=0	shield_defense=0	skill_list={@s_full_magic_defence}	npc_ai={[default_npc]}	category={}	race=human	sex=male	undying=1	can_be_attacked=0	corpse_time=15	no_sleep_mode=0	agro_range=1000	ground_high={140;0;0}	ground_low={60;0;0}	exp=429634523.0	org_hp=0	org_hp_regen=0	org_mp=0	org_mp_regen=0	collision_radius={0.1;0.1}	collision_height={0.1;0.1}	str=40	int=21	dex=30	wit=20	con=43	men=20	base_attack_type=fist	base_attack_range=40	base_damage_range={0;0;80;120}	base_rand_dam=0	base_physical_attack=0	base_critical=0	physical_hit_modify=0	base_attack_speed=0	base_reuse_delay=0	base_magic_attack=0	base_defend=0	base_magic_defend=0	physical_avoid_modify=0	soulshot_count=0	spiritshot_count=0	hit_time_factor=0	item_make_list={}	corpse_make_list={}	additional_make_list={}	additional_make_multi_list={}	hp_increase=0	mp_increase=0	safe_height=0	drop_herb=0	npc_end
<...>
npc_begin	citizen	32349	[rignos]	level=1	acquire_exp_rate=0	acquire_sp=0	unsowing=1	clan={}	ignore_clan_list={}	clan_help_range=0	slot_chest=[]	slot_rhand=[skull_graver]	slot_lhand=[]	shield_defense_rate=0	shield_defense=0	skill_list={@s_race_undead;@s_full_magic_defence}	npc_ai={[rignos]}	category={}	race=undead	sex=male	undying=1	can_be_attacked=0	corpse_time=15	no_sleep_mode=0	agro_range=1000	ground_high={120;0;0}	ground_low={80;0;0}	exp=1.0	org_hp=2444	org_hp_regen=0	org_mp=2444	org_mp_regen=0	collision_radius={17;17}	collision_height={30.5;30.5}	str=40	int=21	dex=30	wit=20	con=43	men=20	base_attack_type=fist	base_attack_range=40	base_damage_range={0;0;80;120}	base_rand_dam=0	base_physical_attack=500	base_critical=0	physical_hit_modify=0	base_attack_speed=230	base_reuse_delay=253	base_magic_attack=500	base_defend=500	base_magic_defend=500	physical_avoid_modify=0	soulshot_count=0	spiritshot_count=0	hit_time_factor=0	item_make_list={}	corpse_make_list={}	additional_make_list={}	additional_make_multi_list={}	hp_increase=0	mp_increase=0	safe_height=0	drop_herb=0	npc_end
<...>
--- file end ---

Рабочий файл ПОСЛЕ работы инжектора
-- file begin --
<...>
//fortress npc {$W 0} {$C 0} {$P 1}
npc_begin	citizen	32468	[clear_npc]		npc_ai={[default_npc]}	npc_end
<...>
//npc_begin	citizen	32349	[rignos]	level=1	acquire_exp_rate=0	acquire_sp=0	unsowing=1	clan={}	ignore_clan_list={}	clan_help_range=0	slot_chest=[]	slot_rhand=[skull_graver]	slot_lhand=[]	shield_defense_rate=0	shield_defense=0	skill_list={@s_race_undead;@s_full_magic_defence}	npc_ai={[default_npc]}	category={}	race=undead	sex=male	undying=0	can_be_attacked=0	corpse_time=15	no_sleep_mode=0	agro_range=1000	ground_high={120;0;0}	ground_low={80;0;0}	exp=1.0	org_hp=2444	org_hp_regen=0	org_mp=2444	org_mp_regen=0	collision_radius={17;17}	collision_height={30.5;30.5}	str=40	int=21	dex=30	wit=20	con=43	men=20	base_attack_type=fist	base_attack_range=40	base_damage_range={0;0;80;120}	base_rand_dam=0	base_physical_attack=500	base_critical=0	physical_hit_modify=0	base_attack_speed=230	base_reuse_delay=253	base_magic_attack=500	base_defend=500	base_magic_defend=500	physical_avoid_modify=0	soulshot_count=0	spiritshot_count=0	hit_time_factor=0	item_make_list={}	corpse_make_list={}	additional_make_list={}	additional_make_multi_list={}	hp_increase=0	mp_increase=0	safe_height=0	drop_herb=0	npc_end
<...>

//iop race {$W 1} {$C 1} {$P 0}
npc_begin	citizen	32468	[rignos]	npc_ai={[rignos]}	undying=1	level=1	acquire_exp_rate=0	acquire_sp=0	unsowing=1	clan={}	ignore_clan_list={}	clan_help_range=0	slot_chest=[]	slot_rhand=[skull_graver]	slot_lhand=[]	shield_defense_rate=0	shield_defense=0	skill_list={@s_race_undead;@s_full_magic_defence}	category={}	race=undead	sex=male	can_be_attacked=0	corpse_time=15	no_sleep_mode=0	agro_range=1000	ground_high={120;0;0}	ground_low={80;0;0}	exp=1.0	org_hp=2444	org_hp_regen=0	org_mp=2444	org_mp_regen=0	collision_radius={17;17}	collision_height={30.5;30.5}	str=40	int=21	dex=30	wit=20	con=43	men=20	base_attack_type=fist	base_attack_range=40	base_damage_range={0;0;80;120}	base_rand_dam=0	base_physical_attack=500	base_critical=0	physical_hit_modify=0	base_attack_speed=230	base_reuse_delay=253	base_magic_attack=500	base_defend=500	base_magic_defend=500	physical_avoid_modify=0	soulshot_count=0	spiritshot_count=0	hit_time_factor=0	item_make_list={}	corpse_make_list={}	additional_make_list={}	additional_make_multi_list={}	hp_increase=0	mp_increase=0	safe_height=0	drop_herb=0	npc_end
--- file end ---

Нелинейные файлы

Импортируемый файл:
-- file begin --
//{$W 1} {$C 0} {$P 1}
fishing_begin
skill_begin	skill_name=[mana_potion2]	get_lv=1	lv_up_sp=0	auto_get=false	item_needed={{[donation_coin];25}}	skill_end
skill_begin	skill_name=[s_divine_inspiration5]	get_lv=1	lv_up_sp=0	auto_get=false	item_needed={{[donation_coin];5}}	skill_end
fishing_end

//{$W 0}
judicator_begin
skill_begin	skill_name=[s_battle_force1]	get_lv=77	lv_up_sp=14700000	auto_get=false	item_needed={}	skill_end
skill_begin	skill_name=[s_spell_force1]	get_lv=77	lv_up_sp=14700000	auto_get=false	item_needed={}	skill_end
judicator_end
--- file end ---

Рабочий файл ДО работы инжектора
-- file begin --
<...>
judicator_begin
include_inspector
skill_begin	skill_name=[s_health1]	get_lv=76	lv_up_sp=12500000	auto_get=false	item_needed={}	skill_end
skill_begin	skill_name=[s_wisdom1]	get_lv=76	lv_up_sp=12500000	auto_get=false	item_needed={}	skill_end
skill_begin	skill_name=[s_battle_force1]	get_lv=77	lv_up_sp=14700000	auto_get=false	item_needed={}	skill_end
skill_begin	skill_name=[s_skill_mastery_fighter1]	get_lv=77	lv_up_sp=14700000	auto_get=false	item_needed={}	skill_end
skill_begin	skill_name=[s_spell_force1]	get_lv=77	lv_up_sp=14700000	auto_get=false	item_needed={}	skill_end
skill_begin	skill_name=[s_soul_rage1]	get_lv=78	lv_up_sp=16000000	auto_get=false	item_needed={}	skill_end
skill_begin	skill_name=[s_final_form1]	get_lv=79	lv_up_sp=80000000	auto_get=false	item_needed={}	skill_end
skill_begin	skill_name=[s_lightning_barrier1]	get_lv=80	lv_up_sp=150000000	auto_get=false	item_needed={}	skill_end
judicator_end
<...>
fishing_begin
skill_begin	skill_name=[s_fishing_cast]	get_lv=1	lv_up_sp=0	auto_get=false	item_needed={{[adena];1000}}	skill_end
skill_begin	skill_name=[s_fishing_mastery1]	get_lv=1	lv_up_sp=0	auto_get=false	item_needed={{[adena];10}}	skill_end
skill_begin	skill_name=[s_fishing_reeling1]	get_lv=1	lv_up_sp=0	auto_get=false	item_needed={{[adena];10}}	skill_end
fishing_end
<...>
--- file end ---

Рабочий файл ПОСЛЕ работы инжектора
-- file begin --
<...>
judicator_begin
skill_begin	skill_name=[s_battle_force1]	get_lv=77	lv_up_sp=14700000	auto_get=false	item_needed={}	skill_end
skill_begin	skill_name=[s_spell_force1]	get_lv=77	lv_up_sp=14700000	auto_get=false	item_needed={}	skill_end
judicator_end
<...>
fishing_begin
skill_begin	skill_name=[mana_potion2]	get_lv=1	lv_up_sp=0	auto_get=false	item_needed={{[donation_coin];25}}	skill_end
skill_begin	skill_name=[s_divine_inspiration5]	get_lv=1	lv_up_sp=0	auto_get=false	item_needed={{[donation_coin];5}}	skill_end
skill_begin	skill_name=[s_fishing_cast]	get_lv=1	lv_up_sp=0	auto_get=false	item_needed={{[adena];1000}}	skill_end
skill_begin	skill_name=[s_fishing_mastery1]	get_lv=1	lv_up_sp=0	auto_get=false	item_needed={{[adena];10}}	skill_end
skill_begin	skill_name=[s_fishing_reeling1]	get_lv=1	lv_up_sp=0	auto_get=false	item_needed={{[adena];10}}	skill_end
fishing_end
<...>
--- file end ---