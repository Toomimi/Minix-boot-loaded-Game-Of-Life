ASM_BIN=nasm
ASM_SRC=game_of_life_bl

all: assemble
assemble: $(ASM_SRC).asm
	pkgin in nasm
	$(ASM_BIN) -f bin -w+all -w+error -o $(ASM_SRC).o $(ASM_SRC).asm
clean:
	rm -f $(ASM_SRC).o
