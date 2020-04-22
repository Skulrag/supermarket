USE `essentialmode`;

CREATE TABLE `shops_items` (
	`id` int(11) NOT NULL AUTO_INCREMENT,
	`store` varchar(100) NOT NULL,
	`item` varchar(100) NOT NULL,
	`price` int(11) NOT NULL,
    `quantity` int(11) NOT NULL,

	PRIMARY KEY (`id`)
);

CREATE TABLE `shops_list` (
	`id` int(11) NOT NULL AUTO_INCREMENT,
	`store` varchar(100) NOT NULL,
	`owner` varchar(100) NOT NULL,
	`price` int(11) NOT NULL,
    `forsale` boolean,

	PRIMARY KEY (`id`)
);

INSERT INTO `shops_list` (store, owner, price, forsale) VALUES
	('TwentyFourSeven','',0, false),
	('TwentyFourSeven1','',0, false),
	('TwentyFourSeven2','',0, false),
	('TwentyFourSeven3','',0, false),
	('TwentyFourSeven4','',0, false),
	('TwentyFourSeven5','',0, false),
	('TwentyFourSeven6','',0, false),
	('TwentyFourSeven7','',0, false),
    ('RobsLiquor','',0, false),
	('RobsLiquor1','',0, false),
	('RobsLiquor2','',0, false),
	('RobsLiquor3','',0, false),
	('RobsLiquor4','',0, false),
	('RobsLiquor5','',0, false),
	('RobsLiquor6','',0, false),
	('RobsLiquor7','',0, false),
	('RobsLiquor8','',0, false),
	('LTDgasoline','',0, false),
	('LTDgasoline1','',0, false)
	('LTDgasoline2','',0, false)
	('LTDgasoline3','',0, false)
	('LTDgasoline4','',0, false)
;