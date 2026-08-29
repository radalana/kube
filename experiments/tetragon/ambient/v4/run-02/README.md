ambient-v4-run-02
Status: technically valid, not used as final ambient baseline
Reason: post-start collector verification introduced
three attributable terminal-shell-container events

# зачем считать UniqueExecIDs
raw events показывает события где teetrsgon policy сработала, но один и тот же процесс иногда создает несколько записей дял одной и той же полиси, потому записывает сколько раз был вызван хук.
