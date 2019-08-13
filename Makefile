deploy:
	bundle exec jekyll build
	docker-compose build
	docker-compose up -d
