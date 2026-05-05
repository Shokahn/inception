COMPOSE = docker-compose -f srcs/docker-compose.yml
DATA    = $(HOME)/data

all: $(DATA)/db $(DATA)/wp
	$(COMPOSE) up --build -d

$(DATA)/db:
	mkdir -p $(DATA)/db

$(DATA)/wp:
	mkdir -p $(DATA)/wp

down:
	$(COMPOSE) down

clean: down
	$(COMPOSE) down -v --rmi all

fclean: clean
	rm -rf $(DATA)

re: fclean all

.PHONY: all down clean fclean re
