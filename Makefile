clean: # template for cleaning up work dirs
	@read -p "Are you sure you want to clean the directory? [y/N] " confirm && [ "$$confirm" = "y" ]
	# find . -maxdepth 1 -not -path '.' -exec trash {} +
