# Security Policy

## Supported Versions

Use this section to tell people about which versions of your project are
currently being supported with security updates.

| Version | Supported          |
| ------- | ------------------ |
| 5.1.x   | :white_check_mark: |
| 5.0.x   | :x:                |
| 4.0.x   | :white_check_mark: |
| < 4.0   | :x:                |

## Reporting a Vulnerability

Use this section to tell people how to report a vulnerability.

Tell them where to go, how often they can expect to get an update on a
reported vulnerability, what to expect if the vulnerability is accepted or
declined, etc.
Git--fast-version-control
Search entire site...
About
Documentation
Reference
Book
Videos
External Links
Downloads
Community
This book is available in English.

Full translation available in

azərbaycan dili,
български език,
Deutsch,
Español,
Français,
Ελληνικά,
日本語,
한국어,
Nederlands,
Русский,
Slovenščina,
Tagalog,
Українська
简体中文,
Partial translations available in

Čeština,
Македонски,
Polski,
Српски,
Ўзбекча,
繁體中文,
Translations started for

Беларуская,
فارسی,
Indonesian,
Italiano,
Bahasa Melayu,
Português (Brasil),
Português (Portugal),
Svenska,
Türkçe.
The source of this book is hosted on GitHub.
Patches, suggestions and comments are welcome.

Chapters ▾ 2nd Edition
5.3 Paylanmış Git - Layihənin Saxlanılması
Layihənin Saxlanılması
Bir layihəyə necə effektiv dəstək verəcəyinizi bilməklə yanaşı, çox güman ki, onu necə qorumağı da bilməlisiniz. Bu, sizə göndərilən format-patch vasitəsi ilə yaradılan patch-ların qəbul edilməsindən və tətbiq edilməsindən və ya proyektinizə uzaqdan əlavə etdiyiniz depolar üçün uzaq filiallarda dəyişikliklərin birləşdirilməsindən ibarət ola bilər. Kanonik bir depo saxlamağınızdan və ya patchların doğrulanmasından və ya təsdiqlənməsindən kömək istəməyinizdən asılı olmayaraq, işinizi digər dəstəkçilər üçün ən aydın və uzun müddət ərzində davamlı olacaq şəkildə qəbul etməli olduğunuzu bilməlisiniz.

Mövzu Branch’larında İşləmək
Yeni işə inteqrasiya etməyi düşünəndə ümumiyyətlə onu bir mövzu branch-ında yəni, bu yeni işi sınamaq üçün xüsusi hazırlanmış müvəqqəti branch-da sınamaq daha yaxşı fikirdir. Bu yolla, bir patch-ı xüsusi olaraq tweak etmək və işə qayıtmaq üçün vaxtınız olmadıqda qoyub getmək asandır. Çalışacağınız işin mövzusuna, məsələn ruby_client və ya buna bənzər təsvir olunan bir şeyə əsaslanaraq sadə bir branch adını yaratsanız, bir müddət tərk etməli və daha sonra geri qayıtmalı olsanız belə asanlıqla yadda saxlaya bilərsiniz. Git layihəsinin aparıcısı bu branch-ları da sc/ruby_client kimi genişləndirməyə çalışır və bu işə dəstək verən şəxs üçün sc qısa formada olur. Yadınızdadırsa, bu şəkildə master branch-nıza əsaslanan branch yarada bilərsiniz:

$ git branch sc/ruby_client master
Və ya dərhal ona keçid etmək istəyirsinizsə, checkout -b seçimindən istifadə edə bilərsiniz:

$ git checkout -b sc/ruby_client master
İndi aldığınız dəstəklənmiş işi bu mövzu branch-na əlavə etməyə və daha uzunmüddətli branch-lar birləşdirməyə hazırsınız.

Elektron Poçtdan Patch’ların Tətbiq Olunması
Layihənizə inteqrasiya edilməsi lazım olan bir e-poçt üzərindən bir patch alsanız, qiymətləndirmə üçün mövzu branch-da patch tətbiq etməlisiniz. E-poçt patch-nı tətbiq etməyin iki yolu var:git apply və ya git am ilə.

Tətbiqetmə ilə Patch Tətbiq Olunması
Patchi git diff və ya Unix diff əmri ilə yaradan birisindən almış olsanız (tövsiyə edilmir; növbəti hissəyə baxın), git apply əmri ilə tətbiq edə bilərsiniz. Patch-ı /tmp/patch-ruby-client.patch-də saxladığınızı düşünürsünüzsə, belə birşey tətbiq edə bilərsiniz:

$ git apply /tmp/patch-ruby-client.patch
Bu, işlədiyiniz qovluqdakı faylları dəyişdirir. Patch tətbiq etmək demək olar ki, eynidir - tətbiq üçün patch -p1 komanda daha paranoid olsa da, patch-dan daha az qeyri-səlis matçları qəbul edir. Ayrıca git diff formatında təsvir edildiyi təqdirdə fayl əlavə edir, silir və adını dəyişir, hansı ki patch bunu etmir. Nəhayət, git apply hər şeyin tətbiq olunduğu və ya heç birinin olmadığı “apply all or abort all” modelidir, halbuki patch qismən patchfiles tətbiq edə bilər. git apply patch-dan daha çox mühafizəkardır. Bu sizin üçün commit yaratmayacaq - onu işlədikdən sonra manual təqdim olunan dəyişiklikləri səhnələşdirməli və etməlisiniz. Siz onu tətbiq etməyə çalışmadan əvvəl bir patch-ın təmiz tətbiq olunduğunu görmək üçün git apply ilə yoxlaya bilərsiniz - bu zaman git apply --check-i patch ilə yoxlayın:

$ git apply --check 0001-see-if-this-helps-the-gem.patch
error: patch failed: ticgit.gemspec:1
error: ticgit.gemspec: patch does not apply
Əgər çıxış yoxdursa, patch təmiz tətbiq olunmalıdır. Bu əmr həmçinin çek uğursuz olduqda sıfır olmayan bir status ilə çıxır, bu zaman istədiyiniz təqdirdə skriptlərdə istifadə edə bilərsiniz.

Patch’ı am ilə Tətbiq Etmək
Əgər dəstəkçi Git istifadəçisidirsə və patch-ların düzəldilməsi üçün format-patch əmrindən istifadə etmək kifayətdirsə, sizin işiniz daha asandır, çünki patch-da müəllif məlumatları və sizin üçün commit mesajı var. Əgər edə bilsəniz, dəstəkçilərinizi sizin üçün patch-lar yaratmaq üçün fərqli olan format-patch istifadə etməyə təşviq edin. Siz yalnız köhnə patch-lar və bu kimi şeylər üçün git apply işlətməlisiniz.

format-patch tərəfindən yaradılan bir patch tətbiq etmək üçün git am istifadə edirsiniz (əmr "poçt qutusundan bir sıra patchlar tətbiq etmək üçün istifadə edildiyi üçün" am adlanır). Texniki olaraq, git am bir və ya daha çox e-poçt mesajını bir mətn sənədində saxlamaq üçün sadə, düz mətn formatı olan bir mbox faylını oxumaq üçün qurulmuşdur. Belə bir şey kimi görünəcəkdir:

From 330090432754092d704da8e76ca5c05c198e71a8 Mon Sep 17 00:00:00 2001
From: Jessica Smith <jessica@example.com>
Date: Sun, 6 Apr 2008 10:17:23 -0700
Subject: [PATCH 1/2] Add limit to log function

Limit log functionality to the first 20
Bu əvvəlki hissədə gördüyünüz git format-patch əmrinin çıxışının başlanğıcıdır; eyni zamanda etibarlı bir mbox e-poçt formatını təmsil edir. Kimsə git göndərmə e-poçtundan istifadə edərək sizə patchdan elektron poçt göndərsə və bunu mbox formatına yükləsəniz, git am-ı o mbox faylına yönləndirə bilərsiniz və o, gördüyü bütün patchları tətbiq etməyə başlayacaq. Bir neçə e-poçtu mbox formatında saxlaya bilən bir poçt müştərisi işlətsəniz, bütün patch silsilələrini bir faylda saxlaya bilərsiniz və sonra onları bir-bir tətbiq etmək üçün git am istifadə edə bilərsiniz.

Ancaq kimsə git format-patch vasitəsi ilə yaradılan bir patch sənədini bilet sisteminə və ya bənzər bir şeyə yükləyibsə, yerli olaraq saxlaya bilər və sonra diskinizdə saxlanan həmin sənədi tətbiq etmək üçün ötürə bilərsiniz:

$ git am 0001-limit-log-function.patch
Applying: Add limit to log function
Təmiz tətbiq olunduğunu və avtomatik olaraq sizin üçün yeni bir commit yaratdığını görə bilərsiniz. Müəllif haqqında məlumat e-poçtun From və Date başlıqlarından götürülür və commit mesajı e-poçtun Subject və gövdəsindən (patchdan əvvəl) götürülür. Məsələn, bu patch yuxarıdakı mbox nümunəsindən tətbiq olsaydı, əmələ gələn əməl buna bənzəyəcəkdi:

$ git log --pretty=fuller -1
commit 6c5e70b984a60b3cecd395edd5b48a7575bf58e0
Author:     Jessica Smith <jessica@example.com>
AuthorDate: Sun Apr 6 10:17:23 2008 -0700
Commit:     Scott Chacon <schacon@gmail.com>
CommitDate: Thu Apr 9 09:19:06 2009 -0700

   Add limit to log function

   Limit log functionality to the first 20
Commit məlumatında patch tətbiq edən şəxs və tətbiq olunan vaxt göstərilir. Author məlumatları əvvəlcə patch yaradan və əvvəlcədən yaradan şəxsdir.

Ancaq patch-ın təmiz tətbiq edilməməsi mümkündür. Bəlkə də əsas branch-nız patch tikilmiş branch-dan çox uzaqlaşıb və ya patch hələ tətbiq etmədiyiniz başqa bir patchdan asılıdır. Bu vəziyyətdə git am prosesi uğursuz olacaq və nə etmək istədiyinizi soruşacaq:

$ git am 0001-see-if-this-helps-the-gem.patch
Applying: See if this helps the gem
error: patch failed: ticgit.gemspec:1
error: ticgit.gemspec: patch does not apply
Patch failed at 0001.
When you have resolved this problem run "git am --resolved".
If you would prefer to skip this patch, instead run "git am --skip".
To restore the original branch and stop patching run "git am --abort".
Bu əmr, ziddiyyətli birləşmə və ya yenidən işə salmaq kimi problemləri olan hər hansı bir sənəddə konflikt işarələri qoyur. Bu məsələni eyni şəkildə həll edə bilərsiniz - münaqişəni həll etmək üçün faylı düzəldin, yeni faylı hazırlayın və sonra git am --resolved əmrini işə salıb, növbəti patcha davam edin:

$ (fix the file)
$ git add ticgit.gemspec
$ git am --resolved
Applying: See if this helps the gem
Git’in konflikti həll etmək üçün bir az daha ağıllı bir şəkildə cəhd etməsini istəyirsinizsə, ona -3 seçimini yönləndirə bilərsiniz, bu da Git cəhdini üç tərəfli birləşməyə məcbur edir. Bu seçim standart olaraq edilmir, çünki patch-ın baza olaraq götürüldüyü əmr deponuzda yoxdursa o işləməyəcək. Əgər bu commit-niz varsa - patch public bir commit üzərində qurulmuşdursa - o zaman -3 seçimi ziddiyyətli patch-ın tətbiqi ilə bağlı daha ağıllı seçimdir:

$ git am -3 0001-see-if-this-helps-the-gem.patch
Applying: See if this helps the gem
error: patch failed: ticgit.gemspec:1
error: ticgit.gemspec: patch does not apply
Using index info to reconstruct a base tree...
Falling back to patching base and 3-way merge...
No changes -- Patch already applied.
Bu vəziyyətdə, -3 variant olmadan patch konflikt hesab edilə bilər. -3 variant istifadə edildiyi üçün patch təmiz tətbiq olunur.

Bir mbox-dan bir sıra patchlar tətbiq etsəniz, am əmrini interaktiv rejimdə işlətmək olar, bu tapdığı hər patchda dayanır və tətbiq etməyinizi xahiş edir:

$ git am -3 -i mbox
Commit Body is:
--------------------------
See if this helps the gem
--------------------------
Apply? [y]es/[n]o/[e]dit/[v]iew patch/[a]ccept all
Bir çox patch-ın saxlanması yaxşıdır, çünki əvvəlcə patch-ın nə olduğunu xatırlamadığınız təqdirdə görə bilərsiniz və ya əvvəlcədən patch tətbiq etməyə bilərsiniz. Mövzunuz üçün bütün patch-lar tətbiq edildikdə və branch-ınıza verildikdə onları daha uzun bir branch-a inteqrasiya edib etməyəcəyinizi və ya necə etməli olduğunuzu seçə bilərsiniz.

Uzaq Branch’ları Yoxlamaq
Sizin töhfəniz öz depolarını quran, bir sıra dəyişikliklər edən Git istifadəçisindən gəlirsə və URL-i depozitə göndərirsinizsə və dəyişikliklərin olduğu uzaq branch-ın adını çəksəniz, bunları əlavə edə bilərsiniz, uzaq və local olmaqla birləşdirəcəkdir.

Məsələn, Jessica sizə öz depolarının ruby-client branch-ındə yeni bir xüsusiyyəti olduğunu söyləyən bir e-poçt göndərsə, uzaqdan əlavə edərək local branch-ı yoxlamaqla sınaya bilərsiniz:

$ git remote add jessica git://github.com/jessica/myproject.git
$ git fetch jessica
$ git checkout -b rubyclient jessica/ruby-client
Daha sonra başqa bir əla bir xüsusiyyəti özündə birləşdirən başqa bir branch ilə yenidən sizə e-poçt göndərərsə, birbaşa quraşdırma olduğunuz üçün birbaşa fetch və checkout edə bilərsiniz.

Bir şəxslə ardıcıl işləmək ən faydalı seçimdir. Kimsə bir müddət ərzində bir qatqı təmin edəcək tək bir patch-a sahibdirsə, onu elektron poçtla qəbul etmək hər kəsdən öz serverini işə salmağı tələb etməkdən və bir neçə patch almaq üçün daim əlavə etmək və silmək məcburiyyətində qalmaqdan daha az vaxt tələb edə bilər. Hər biri yalnız bir patch və ya iki töhfə verən biri üçün yüzlərlə uzaqdan istifadə etmək istəməyiniz mümkün deyil. Bununla birlikdə, skriptlər və ev sahibi xidmətləri bunu asanlaşdıra bilər - bu, sizin necə inkişaf etdiyinizə və töhfəçilərinizin necə inkişaf etdiyinə bağlıdır.

Bu yanaşmanın digər üstünlüyü odur ki, commit-lərin tarixini də əldə etməyinizdir. Birləşmə ilə bağlı qanuni problemləriniz ola bilər, ancaq tarixinizdə işlərinin harada dayandığını bilirsiniz; düzgün bir üç tərəfli birləşmə bir -3 təmin etmək əvəzinə standartdır və patchin daxil olacağınız bir public commit-dən yaradıldığına ümid edirik. Daimi bir adamla işləmirsinizsə, lakin hələ də bu şəkildə onlardan pull etmək istəsəniz, git pull əmrinə uzaqdakı depo URL-ni təqdim edə bilərsiniz. Bu birdəfəlik çəkim aparır və URL-i uzaqdan istinad kimi saxlamır:

$ git pull https://github.com/onetimeguy/project
From https://github.com/onetimeguy/project
 * branch            HEAD       -> FETCH_HEAD
Merge made by the 'recursive' strategy.
Nəyin Təqdim Olunduğunu Müəyyənləşdirmək
İndi dəstəkdə əməyi olanlardan ibarət bir mövzu branch-nız var. Bu anda nə etmək istədiyinizi təyin edə bilərsiniz. Bu bölmə bir neçə əmrini yenidən nəzərdən keçirir ki, bunları əsas branch-ınıza birləşdirdiyiniz təqdirdə tətbiq edəcəyinizi nəzərdən keçirmək üçün necə istifadə etdiyinizi görə bilərsiniz.

Bu branch-da olan, lakin master branch-ınızda olmayan bütün commit-lərin icmalını almaq çox vaxt faydalıdır. Branch-ın adından əvvəl --not seçimi əlavə etməklə master branch-dakı commit-ləri istisna edə bilərsiniz. Bu, əvvəllər istifadə etdiyimiz master..contrib formatı ilə eyni şeyi edir. Məsələn, töhfəçiniz sizə iki patch göndərirsə və orada həmin patch-ları tətbiq edən contrib adlı bir branch yaradırsınızsa, bunu edə bilərsiniz:

$ git log contrib --not master
commit 5b6235bd297351589efc4d73316f0a68d484f118
Author: Scott Chacon <schacon@gmail.com>
Date:   Fri Oct 24 09:53:59 2008 -0700

    See if this helps the gem

commit 7482e0d16d04bea79d0dba8988cc78df655f16a0
Author: Scott Chacon <schacon@gmail.com>
Date:   Mon Oct 22 19:38:36 2008 -0700

    Update gemspec to hopefully work better
Hər bir tapşırığın nəyi dəyişdiyini görmək üçün -p seçimini git log-a keçə biləcəyinizi və hər bir commit-ə təqdim olunan fərqi əlavə edəcəyinizi unutmayın.

Bu mövzu branch-nı başqa bir branch-la birləşdirsəniz, nə olacağının tam fərqini görmək üçün düzgün nəticələr əldə etmək üçün qəribə bir hiylədən istifadə etməli ola bilərsiniz. Bunu idarə etməyi düşünə bilərsiniz:

$ git diff master
Bu əmr sizə bir fərq verir, ancaq sizi yanılda bilər. Mövzu branch-nı ondan yaratdığınızdan bəri master branch-nız irəliləyibsə, qəribə görünən nəticələr əldə edəcəksiniz. Bu, Git birbaşa olduğunuz mövzu bölməsinin son əmrlərinin anketlərini və magistr bölməsindəki son əmrlərin snapshotlarını birbaşa müqayisə etməsi nəticəsində baş verir. Məsələn, master branch-da bir sətir əlavə etdinizsə, snapshotların birbaşa müqayisəsi mövzu branch-na bu sətri silmək kimi görünəcəkdir.

Əgər master mövzu branch-nın birbaşa əcdadıdırsa, bu problem deyil; lakin iki tarix ayrılıbsa, fərqli görünəcək ki, mövzu branch-da bütün yeni materialları əlavə etməyiniz və master branch-na xas olan hər şeyi silmək olar.

Həqiqətən görmək istədiyiniz mövzu barnch-na əlavə edilmiş dəyişikliklər - bu branch-ı master ilə birləşdirsəniz təqdim edəcəyiniz işlərdir. Bunu Git-in mövzu branch-dakı son commiti ana branch-ı ilə olan ilk ortaq əcdadı ilə müqayisə etməklə etməlisiniz.

Texniki cəhətdən, ortaq əcdadını aydın şəkildə müəyyənləşdirə və sonra fərqinizi işlətməklə bunu edə bilərsiniz:

$ git merge-base contrib master
36c7dba2c95e6bbb78dfa822519ecfec6e1ca649
$ git diff 36c7db
və ya:

$ git diff $(git merge-base contrib master)
Ancaq bunların heç biri xüsusilə əlverişli deyildir, buna görə Git eyni şeyi etmək üçün başqa bir stend təqdim edir: üç nöqtəli sintaksis. git diff əmri kontekstində başqa bir branch-dan sonra üç dövr qoya bilər və olduğunuz branch-ın son törəməsi ilə başqa bir branch ilə ümumi əcdadı arasında fərq qoymaq üçün:

$ git diff master...contrib
Bu əmr yalnız cari mövzu branch-ın master ilə ortaq əcdadından bəri tanıtdığı işləri göstərir. Yadda saxlamaq üçün çox faydalı bir sintaksisdir.

İşə İnteqrasiya
Mövzu branch-nızdakə bütün işlər daha təməl branch-a birləşdirilməyə hazır olduqda bunu belə etmək olar; Bundan əlavə, layihənizi qorumaq üçün hansı ümumi iş axını istifadə etmək istəyirsiniz? Bir neçə seçiminiz var, buna görə onlardan bir neçəsini əhatə edəcəyik.

İş Axınlarının Birləşdirilməsi
Bir əsas iş axını, sadəcə bütün işləri birbaşa master branch-ınıza birləşdirməkdir. Bu ssenaridə, əsasən sabit kodu ehtiva edən master branch-nız var. Tamamladığınızı düşündüyünüz bir mövzu branch-da işləmisinizsə və ya başqasının töhfəsini verdiyinizi və təsdiq etdiyinizi görsəniz, onu master branch-nıza birləşdirirsiniz, birləşdirilmiş mövzu branch-nı silib yenidən təkrarlayacaqsınız.

Məsələn, əgər ruby_client və php_client adlı Bir neçə mövzu branch-ı olan tarix kimi görünən iki branch-da işləyən bir depomuz varsa və ruby_client-i və ardınca php_client-i birləşdirsəniz tarixniz Mövzu branch-ı birləşmədən sonra kimi görünəcəkdir.

Bir neçə mövzu branch-ı olan tarix
Figure 73. Bir neçə mövzu branch-ı olan tarix
Mövzu branch-ı birləşmədən sonra
Figure 74. Mövzu branch-ı birləşmədən sonra
Bu, bəlkə də ən sadə iş axınlarıdır, amma tanıdıb təqdim etdiyiniz şeylərə diqqətli olmaq istədiyiniz daha böyük və ya daha sabit layihələrlə məşğul olsanız, problemli ola bilər.

Daha vacib bir layihəniz varsa, iki fazalı birləşmə dövründən istifadə etmək istəyə bilərsiniz. Bu ssenaridə master and develop olan iki uzun filial var, master yalnız çox sabit bir buraxılma kəsildikdə və bütün yeni kod develop branch-na inteqrasiya edildikdə yeniləndiyini müəyyənləşdirirsiniz.

Mütəmadi olaraq bu branch-ların hər ikisini public depolarına aparırsınız. Hər dəfə (Mövzu branch-ı birləşmədən əvvəl) birləşmək üçün yeni bir mövzu branch-ı varsa, onu develop-a (Mövzu branch-ı birləşmədən sonra) birləşdirirsiniz; sonra bir etiketi etiketlədikdə, stabil develop branch-ın olduğu yerə master sürətlə irəliləyir (Mövzu branch-ı buraxıldıqdan sonra).

Mövzu branch-ı birləşmədən əvvəl
Figure 75. Mövzu branch-ı birləşmədən əvvəl
Mövzu branch-ı birləşmədən sonra
Figure 76. Mövzu branch-ı birləşmədən sonra
Mövzu branch-ı buraxıldıqdan sonra
Figure 77. Mövzu branch-ı buraxıldıqdan sonra
Bu yolla, insanlar proyektlərinizin depolarını klonlaşdırdıqda son sabit versiyasını hazırlamaq üçün master-i yoxlaya və asanlıqla bu günə qədər davam etdirə bilər və ya daha inkişaf etmiş məzmun olan develop-u yoxlaya bilərlər. Ayrıca, bütün işlərin birləşdirildiyi bir integrate branch-na sahib olmaqla bu anlayışı genişləndirə bilərsiniz. Sonra, bu branch-dakı kod bazası sabit olduqda və testlərdən keçdikdə, onu develop branch-na birləşdirirsiniz; və bu, bir müddət sabit olduqda, master branch-nızı sürətlə irəliyə aparırsınız.

Böyük Birləşən İş Axınları
Git layihəsinin dörd uzun branch-ı var: master, next, və seen (əvəəllər pu --təklif olunan yeniləmələr) yeni iş üçün, və maint yeni iş yerləri üçün. Yardımçılar tərəfindən yeni bir iş təqdim edildikdə, təsvir etdiyimizə bənzər bir şəkildə tərtibatçı depolarında mövzu şöbələrinə toplanır (Paralel töhfə verilmiş mövzu şöbələrinin kompleks seriyasını idarə etmək bax). Bu nöqtədə, təhlükəsiz və istehlaka hazır olub olmadığını və ya daha çox işə ehtiyacı olub olmadığını müəyyən etmək üçün mövzular qiymətləndirilir. Etibarlı olduqları təqdirdə, next birləşdirilir və hər kəs bir-birinə inteqrasiya olunan mövzuları sınaya bilməsi üçün bu branch yuxarı göndərilir.

Paralel töhfə verilmiş mövzu şöbələrinin kompleks seriyasını idarə etmək
Figure 78. Paralel töhfə verilmiş mövzu şöbələrinin kompleks seriyasını idarə etmək
Mövzular hələ də işə ehtiyac duyursa, əvəzinə seen-ə birləşdirilir. Tamamilə sabit olduqları müəyyən edildikdə, mövzular yenidən master-ə birləşdirilir. next və seen branch-ları master tərəfindən yenidən qurulur. Bu o deməkdir ki, master demək olar ki, həmişə irəliləyir, next bəzən rebase olunur və senn daha tez-tez dəyişdirilir:

Mövzu şöbələrini uzunmüddətli inteqrasiya filiallarına birləşdirmək
Figure 79. Mövzu şöbələrini uzunmüddətli inteqrasiya filiallarına birləşdirmək
Bir mövzu branch-ı nəhayət master ilə birləşdirildikdə, depo içərisindən silinir. Git layihəsində, texniki xidmət tələb olunduğu təqdirdə geri çəkilmiş patchları təmin etmək üçün son buraxılışdan kənarlaşdırılan bir maint branch-ı var. Beləliklə, Git depolarını klonlaşdırdığınız zaman, necə olmaq istədiyinizdən və necə töhfə vermək istədiyinizdən asılı olaraq, müxtəlif inkişaf mərhələlərində layihəni qiymətləndirmək üçün yoxlaya biləcəyiniz dörd branch-nız var; və təmirçi onlara yeni töhfələr verməyə kömək etmək üçün strukturlaşdırılmış bir workflow-a malikdir. Git layihəsinin workflow-u ixtisaslaşmışdır. Bunu aydın başa düşmək üçün Git Maintainer’s guide baxa bilərsiniz.

Rebasing və Cherry-Picking İş Axınları
Digər təmirçilər, əsasən xətti bir tarix saxlamaq üçün master branch-nın üstünə töhfə verən işləri rebase və ya cherry-pick-ə üstünlük verirlər. Bir mövzu branch-ında işlədiyinizdə və onu birləşdirmək istədiyinizi müəyyənləşdirdiyinizdə, o branch-a keçin və dəyişiklikləri hazırkı master (və ya develop və s.) branch-ınızda yenidən qurmaq üçün rebase əmrini işə salırsınız. Yaxşı olarsa, master branch-ı sürətlə irəli göndərə bilərsiniz və xətti bir layihə tarixi ilə başa çatacaqsınız.

Təqdim olunan işi bir branch-dan digərinə keçirməyin başqa yolu cherry-picki seçməkdir. Git’də bir cherry-pick, yalnız bir commit üçün bir rebase kimidir. Bu commit-ə daxil edilmiş patchi götürür və onu hazırda işlədiyiniz branch-da yenidən tətbiq etməyə çalışır. Bir mövzu banch-ında bir sıra commit-ləriniz varsa və onlardan yalnız birini birləşdirmək istəsəniz və ya bir mövzu banch-ında yalnız bir əmriniz varsa və yenidən yazmağı yerinə, cherry-picking-i üstün tutursunuzsa,bu daha faydalıdır. Məsələn, belə görünən bir layihəniz var deyək:

Bir cherry-pickdən əvvəl nümunə tarixi
Figure 80. Bir cherry-pickdən əvvəl nümunə tarixi
e43a6 commit-ni master branch-nıza pull etmək istəirsinizsə, bunu işlədə bilərsiniz:

$ git cherry-pick e43a6
Finished one cherry-pick.
[master]: created a0a41a9: "More friendly message when locking the index fails."
 3 files changed, 17 insertions(+), 3 deletions(-)
Bu e43a6-da tətbiq olunan eyni dəyişikliyi irəli çəkir, ancaq tətbiq olunan tarix fərqli olduğundan yeni bir SHA-1 dəyəri əldə edirsiniz. Onda tarixiniz belə görünür:

Cherry-pickdən sonra bir mövzu branch-ından bir commit tarixi
Figure 81. Cherry-pickdən sonra bir mövzu branch-ından bir commit tarixi
İndi mövzu şöbənizi silə və daxil etmək istəmədiyiniz əmrləri ata bilərsiniz.
Rerere
Birləşmə və rebasing mövzusunda çox işlər görürsünüzsə və ya uzun müddətdir davam edən bir mövzu branch-ına davam etdirirsinizsə, Git’in kömək edə biləcəyi “rerere” adlı bir xüsusiyyəti var.

Rerere açılışı “reuse recorded resolution”-dur-- bu, manual konflikt həllini qısaldır. Yenidən işə salındıqda, Git uğurlu birləşmədən əvvəl və sonrakı görüntülər dəstini saxlayacaq və əgər əvvəlcədən düzəltdiyinizə bənzər bir ziddiyyət olduğunu görsəniz, sizi narahat etmədən yalnız son dəfə düzəlişdən istifadə edəcək.

Bu xüsusiyyət iki hissədən ibarətdir: bir konfiqurasiya qəbulu və bir əmr. Konfiqurasiya qəbulu rerere.enabled və qlobal konfiqurasiyanızı qoymaq üçün əlverişlidir:

$ git config --global rerere.enabled true
İndi, münaqişələri həll edən bir birləşmə etdikdə, gələcəkdə ehtiyacınız olduğu halda qətnamə cache-də qeyd ediləcəkdir. Lazım olsa git rerere əmrindən istifadə edərək rerere cache ilə qarşılıqlı əlaqə qura bilərsiniz. Tək başına çağırıldıqda, Git qətnamələr bazasını yoxlayır və cari birləşmə ziddiyyətləri ilə bir eynilik tapmağa və onları həll etməyə çalışır (rerere.enabled doğru olduqda bu avtomatik true olaraq edilir). Yazılacağını görmək, cache-dən xüsusi bir qətnaməni silmək və bütün cache-i təmizləmək üçün alt qruplar var. Rerere-da daha ətraflı əhatə edəcəyik.

Buraxılışlarınızı Etiketləmək
Buraxılışı kəsmək qərarına gəldiyinizdə, yəqin ki, etiket təyin etmək istəyərsiniz ki, irəliləyişin istənilən nöqtəsində yenidən yarada bilərsiniz. Git’in Əsasları-də müzakirə edildiyi kimi yeni bir etiket yarada bilərsiniz. Etiketi qoruyucu olaraq imzalamaq qərarına gəlsəniz, etiketləmə bu kimi bir görünə bilər:

$ git tag -s v1.5 -m 'my signed 1.5 tag'
You need a passphrase to unlock the secret key for
user: "Scott Chacon <schacon@gmail.com>"
1024-bit DSA key, ID F721C45A, created 2009-02-09
Etiketlərinizi imzalamısınızsa, etiketlərinizi imzalamaq üçün istifadə olunan ümumi PGP key-ini paylamaqda probleminiz ola bilər. Git layihəsinin aparıcısı ümumi key-ini depo içərisinə bir qabda kimi əlavə edərək birbaşa həmin məzmuna işarə edən etiket əlavə etməklə bu məsələni həll etdi. Bunu etmək üçün gpg --list-keys işlədərək hansı key-i istədiyinizi anlaya bilərsiniz:

$ gpg --list-keys
/Users/schacon/.gnupg/pubring.gpg
---------------------------------
pub   1024D/F721C45A 2009-02-09 [expires: 2010-02-09]
uid                  Scott Chacon <schacon@gmail.com>
sub   2048g/45D02282 2009-02-09 [expires: 2010-02-09]
Sonra açarı birbaşa Git verilənlər bazasına ixrac edərək boru kəməri ilə ixrac edə bilərsiniz və git hash-object vasitəsilə, bu məzmunu Git içərisinə yeni bir blob yazan və blob-un SHA-1-ni geri qaytara bilərsiniz.

$ gpg -a --export F721C45A | git hash-object -w --stdin
659ef797d181633c87ec71ac3f9ba29fe5775b92
Git-də açarınızın məzmunu olduğundan, hash-object əmrinin sizə verdiyi yeni SHA-1 dəyərini göstərərək birbaşa ona bir etiket yarada bilərsiniz:

$ git tag -a maintainer-pgp-pub 659ef797d181633c87ec71ac3f9ba29fe5775b92
git push --tags işlədirsinizsə, maintainer-pgp-pub etiketi hamıya paylanacaq. Əgər kimsə etiketi yoxlamaq istəyirsə, birbaşa PBP key-nizi bazanı birbaşa verilənlər bazasından çıxararaq GPG-yə idxal edə bilər:

$ git show maintainer-pgp-pub | gpg --import
Bu key-i bütün imzalanmış etiketləri yoxlamaq üçün istifadə edə bilərlər. Ayrıca, etiket mesajına təlimatlar daxil edərsənsə, git show <tag> istifadə edərək, son istifadəçiyə etiket yoxlaması ilə bağlı daha dəqiq göstərişlər verməyə imkan verəcəkdir.

Bir Build Nömrəsi Yaratmaq
Git’in v123 kimi monoton olaraq artan nömrələri və ya hər bir commit ilə birlikdə getmək üçün ekvivalenti olmadığı üçün, bir commit ilə getmək üçün insan tərəfindən oxunan bir ada sahib olmaq istəsəniz, bu commit-in üzərində git describe işlədə bilərsiniz. Buna cavab olaraq, Git bu əməldən daha erkən son etiketin adından ibarət bir sətir yaradır, sonra bu etiketdən bəri verilənlərin sayı, sonra təsvir olunan commit-in qismən SHA-1 dəyəri ilə izlənilir ( Git mənasını verən "g" hərf ilə əvvəl verilir) :

$ git describe master
v1.6.2-rc1-20-g8c5b85c
Bu yolla, bir görüntü ixrac edə və ya insanlar üçün başa düşülən bir şey qura və adlandıra bilərsiniz. Əslində, Git-i Git deposundan klonlanmış mənbə kodundan qursanız, git --version sizə bənzər bir şey verəcəkdir. Birbaşa etiketlədiyiniz bir commit-i təsvir edirsinizsə, sadəcə etiket adını verir.

Varsayılan olaraq, git describe əmrində əlavə etiketlər tələb olunur (-a və ya -s flag-ı ilə yaradılan etiketlər); yüngül (qeyd olunmayan) etiketlərdən də faydalanmaq istəyirsinizsə, --tags seçimini əmrə əlavə edin. Ayrıca, bu simli bir git checkout və ya git show əmrlərini hədəf kimi istifadə edə bilərsiniz, baxmayaraq ki, sonunda qısaldılmış SHA-1 dəyərinə dayanır, buna görə də daimi olaraq etibarlı olmaya bilər. Məsələn, yaxınlarda Linux nüvəsi SHA-1 obyektinin bənzərsizliyini təmin etmək üçün 8-dən 10 simvola qədər atlayır, buna görə köhnə git describe çıxış adları etibarsız sayılır.

Buraxılış Hazırlamaq
İndi bir qurğunu buraxmaq istəyirsiniz. Etmək istədiyiniz işlərdən biri Git istifadə etməyən bu yoxsul ruhlar üçün kodunuzun snapshotunda arxiv yaratmaqdır. Bu əmr git archive-dir:

$ git archive master --prefix='project/' | gzip > `git describe master`.tar.gz
$ ls *.tar.gz
v1.6.2-rc1-20-g8c5b85c.tar.gz
Kimsə bu tarballı açarsa, layihənizin alt hissəsində layihənizin snapshot-larını əldə edər. Eyni şəkildə bir zip arxivini də yarada bilərsiniz, --format=zip seçimini `git archive`əmrinə ötürərək bu mümkündür:

$ git archive master --prefix='project/' --format=zip > `git describe master`.zip
İndi gözəl bir tarballa və veb saytınıza və ya e-poçtla insanlara yükləyə biləcəyiniz bir layihə buraxılışının bir zip arxiviniz var.

Qısa Yol
Layihənizdə nələrin baş verdiyini bilmək istəyən şəxslərin poçt siyahısına e-poçt göndərməyin vaxtı gəldi. Son buraxılışınızdan və ya e-poçtunuzdan bəri proyektinizə əlavə edilmiş bir növ dəyişikliyi tez bir şəkildə əldə etməyin gözəl bir yolu git shortlog əmri istifadə etməkdir. Bu verdiyiniz diapazonda göstərilənlərin hamısını ümumiləşdirir; məsələn, sonuncu buraxılışınız v1.0.1 adlandırılıbsa, aşağıdakılar sizə son buraxılışınızdan bəri görülən işlərin xülasəsini verir:

$ git shortlog --no-merges master --not v1.0.1
Chris Wanstrath (6):
      Add support for annotated tags to Grit::Tag
      Add packed-refs annotated tag support.
      Add Grit::Commit#to_patch
      Update version and History.txt
      Remove stray `puts`
      Make ls_tree ignore nils

Tom Preston-Werner (4):
      fix dates in history
      dynamic version method
      Version bump to 1.0.2
      Regenerated gemspec for version 1.0.2
Siyahıya e-poçt göndərə biləcəyiniz müəllif tərəfindən qruplaşdırılmış v1.0.1-dən bəri verilən commit-lərin təmiz bir xülasəsini alırsınız.

prev | next
About this site
Patches, suggestions, and comments are welcome.Git is a member of Software Freedom Conservancyscroll-to-top
