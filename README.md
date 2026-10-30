# Rematch Gen3 — 0.1.2

Mod independente para G1R 0.3.93 ou superior. Alvos: FireRed, LeafGreen, Ruby, Sapphire e Emerald. Não modifica arquivos do programa nem depende do Floating Glass.

## Download

- [Baixar o mod ZIP da última versão](https://github.com/Jo5-K/rematch-gen3/releases/latest).
- [Código-fonte em ZIP](https://github.com/Jo5-K/rematch-gen3/archive/refs/heads/main.zip).

O manifesto e main.lua estão na raiz do repositório. Tanto o ZIP da release quanto o arquivo “Source code (zip)” têm a estrutura reconhecida pelo importador do G1R. Para instalação manual, extraia a pasta para `mods/rematch_gen3`.

O manifesto declara `github: Jo5-K/rematch-gen3`. O gerenciador do G1R pode consultar novas releases e oferecer a atualização. A release inclui um ZIP próprio do mod; o download de código-fonte também funciona para instalação inicial.

## Instalação e uso

Importe o ZIP pelo gerenciador de mods do G1R e ative Rematch Gen3 no jogo correspondente. Abra as opções do jogo e procure REMATCH GEN3. Depois, converse novamente com um treinador comum que já tenha vencido. Ao terminar o diálogo normal, aparecerá "Rematch?" com SIM / NAO. Selecione SIM para lutar ou NAO para encerrar.

## Configurações

- Ativar revanche: sim/não; padrão sim.
- XP recebido: 0–80%, em passos de 1%; padrão 50%.
- Dinheiro recebido: 0–80%, em passos de 1%; padrão 50%.
- Permitir duplas: sim/não; padrão sim. Exige os Pokémon utilizáveis necessários segundo o jogo.
- Espera em passos: 0–1000, em passos de 50; padrão 0, sem espera. Contada depois de vencer uma revanche.
- Vitórias por treinador: 0–20; padrão 0, sem limite. Limite total de revanches vencidas no histórico deste mod para esse save.

80% significa receber 80% da recompensa normal, não um bônus de 80%. Valores fracionários são arredondados para baixo. As primeiras batalhas, batalhas selvagens e outras batalhas não iniciadas por este mod mantêm as recompensas originais. EVs seguem as regras normais do jogo. O dinheiro configurado se aplica ao prêmio do treinador; Pay Day mantém o comportamento original.

Os ajustes e o histórico usam o armazenamento do mod por partida. O time e os níveis dos adversários são os originais; não há escalonamento de nível.

## Escopo e compatibilidade

Nesta versão, somente scripts diretos de treinadores comuns (tipos 0 e 4; também 2 e 6 em Ruby/Sapphire/Emerald, com registro de contato do PokéNav) são elegíveis. Scripts de rival, ginásios e outros eventos especiais, VS Seeker e combates com dois treinadores são preservados. As continuações de registro do PokéNav dos tipos 2/6 são executadas apenas pelo diálogo original; a revanche é independente. A detecção acompanha o comando trainerbattle executado, inclusive quando chamado por outro roteiro. O diálogo normal continua quando o treinador não é elegível, está em espera ou atingiu o limite.

O mod não apaga flags de treinadores nem executa novamente o roteiro original após a revanche. Utiliza engine_internals para iniciar a batalha e ajustar o cálculo de dinheiro em memória, somente em batalhas marcadas por este mod. Nenhum arquivo da engine é alterado. Outros mods que substituam os mesmos cálculos ou a interação com NPCs podem exigir teste conjunto. Desative antes de atividades de link.

## Validação

Manifesto e compatibilidade Gen3 aprovados pela ferramenta oficial da base local 0.3.96. Testes Lua simulados verificam primeiras batalhas, recompensas 0/50/80%, limites das opções, exclusão de eventos, duplas, intervalo, limite de vitórias e recarga sem multiplicação duplicada. Também verificam a espera pelo término do diálogo, confirmação SIM e recusa NAO. Ainda não validado em uma sessão real do G1R nem nos cinco jogos individualmente. Versão para teste. Regressão com os comandos reais dos dois treinadores de Petalburg Woods (616 e 621) do cache local de Emerald. O mod Dialogue mantém seus hooks, retratos e funções de mensagem; Rematch apenas chama a mensagem pública depois do fechamento do diálogo original. Um diagnóstico da última tentativa fica no armazenamento exclusivo deste mod, sem alterar saves do jogo ou arquivos de outros mods.


## Desenvolvimento e releases

Execute `lua tests/rematch_test.lua .` na raiz para os testes. As fixtures incluem apenas os comandos mínimos dos dois treinadores de Petalburg Woods; não precisam da ROM nem dos arquivos locais do autor.

O workflow oficial de publicação do modkit do G1R publica uma release e um ZIP instalável após alterações de código em `main`. Atualize `version` no manifesto para a próxima versão. O arquivo ZIP publicado recebe exatamente a versão da release.

## English

Standalone optional trainer rematches for FireRed, LeafGreen, Ruby, Sapphire and Emerald on G1R 0.3.93+. Import the release ZIP through MODS, enable Rematch Gen3, then speak to an eligible defeated trainer. Confirm or cancel the rematch. XP and money rewards are configurable from 0 to 80%; double battles, cooldown and win limits can also be configured. Story-sensitive trainers remain excluded.

Version 0.1.2 keeps the same code. Simulated tests cover confirmations, reward bounds, doubles, cooldown, reload and trainer exclusions. Physical Android/ROM validation is not claimed.

Other independent mods: [Glass Menu](https://github.com/Jo5-K/glass-menu-jo5-k) and [2D Battle Menu](https://github.com/Jo5-K/2d-battle-menu-jo5-k).
