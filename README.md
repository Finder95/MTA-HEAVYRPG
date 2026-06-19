# HeavyRPG

Modularny gamemode RPG dla MTA:SA 1.6 z zaawansowanym systemem logowania/rejestracji.

## Funkcje

- CEF UI HTML/CSS/JS renderowane przez `createBrowser` + DX.
- Wlasna obsluga inputu CEF przez `injectBrowserMouseMove`, `injectBrowserMouseDown`, `injectBrowserMouseUp`, `injectBrowserMouseWheel`.
- SQLite przez `dbConnect("sqlite", "data/heavyrpg.db")`.
- Migracja schematu przy starcie resource.
- Hasla przez `passwordHash` / `passwordVerify` z bcrypt w callbacku.
- Rate limiting logowania/rejestracji/resume.
- Lockout konta po wielu blednych haslach.
- Audit log w tabeli `auth_audit`.
- Opcjonalne zapamietanie sesji na danym serialu przez token SHA-256.
- Eksporty dla kolejnych modulow RPG:
  - `isPlayerAuthenticated(player)`
  - `getPlayerAccountId(player)`
  - `getPlayerAccountData(player)`

## Instalacja

1. Wypakuj folder `HeavyRPG` do:

```text
mods/deathmatch/resources/HeavyRPG
```

2. W `mtaserver.conf` dodaj albo uruchom ręcznie:

```xml
<resource src="HeavyRPG" startup="1" protected="0" />
```

albo w konsoli serwera:

```text
start HeavyRPG
```

3. Baza SQLite utworzy się automatycznie jako:

```text
HeavyRPG/data/heavyrpg.db
```

## Struktura

```text
HeavyRPG/
  meta.xml
  shared/
    config.lua
    enums.lua
    utils.lua
  server/
    core/
      boot.lua
      database.lua
      logger.lua
      module_loader.lua
      security.lua
    modules/
      auth/
        validators.lua
        repository.lua
        session.lua
        main.lua
      spawn/
        main.lua
  client/
    core/
      boot.lua
      browser.lua
      local_storage.lua
    modules/
      auth/
        main.lua
  html/auth/
    index.html
    style.css
    app.js
```

## Konfiguracja

Najważniejsze ustawienia są w `shared/config.lua`:

- `auth.bcryptCost` — koszt bcrypt. Domyślnie `12`.
- `auth.maxAccountsPerSerial` — limit kont na serial.
- `auth.failedLoginLock` — blokada po błędnych hasłach.
- `auth.rememberSession.days` — ważność tokenu zapamiętanej sesji.
- `auth.spawn` — miejsce startowe po logowaniu.

## Rozbudowa

Nowy moduł dodajesz jako osobny folder w `server/modules/<name>/main.lua`, rejestrujesz go przez:

```lua
HRP.Modules.register("inventory", module)
```

i dopisujesz nazwę do `HRP.Config.modules.order`.

## Uwaga

Kod jest przygotowany jako solidny starter pod MTA 1.6. Nie był uruchamiany w realnym serwerze MTA w tym środowisku, więc po wrzuceniu na serwer warto odpalić `/debugscript 3` i sprawdzić ewentualne różnice runtime.
