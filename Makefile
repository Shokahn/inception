COMPOSE = docker compose -f srcs/docker-compose.yml
LOGIN   = $(shell grep '^LOGIN=' srcs/.env | cut -d= -f2)
DATA    = /home/$(LOGIN)/data

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
	docker run --rm --entrypoint sh -v $(DATA)/db:/var/lib/mysql mariadb \
		-c "find /var/lib/mysql -mindepth 1 -delete" 2>/dev/null || true
	docker run --rm --entrypoint sh -v $(DATA)/wp:/var/www/html wordpress \
		-c "find /var/www/html -mindepth 1 -delete" 2>/dev/null || true
	rm -rf $(DATA)

re: fclean all

.PHONY: all down clean fclean re
