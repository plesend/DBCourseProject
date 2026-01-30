-- --------------------------
-- Awards
-- --------------------------
INSERT INTO Awards (award_name, award_description) VALUES 
('SHIRASAGI', 'The main award of the year, worthy of only one. Vote for your favorite artist''s album.'),
('RAVE', 'Rave? Of course! This kind of music will not leave you indifferent! Vote for your favorite rave artist''s album.'),
('GOOD O''TIMES', 'Music that stands the test of time. Something that will always remain in our hearts.'),
('MINDSET', 'Music should touch the heart. Vote for the album that gave you the most vivid emotions.'),
('STYLE', 'Know your style? So do we! Vote for the most stylish album.');
COMMIT;

-- --------------------------
-- Musicians
-- --------------------------
INSERT INTO Musicians (name, info, status) VALUES
('Lida', 'Popular singer with a bright style', 'participating'),
('Radiohead', 'Legendary British rock band', 'participating'),
('Noize MC', 'Famous Russian rapper', 'participating'),
('Maneskin', 'Italian rock band', 'participating'),
('Thirteen Karat', 'Russian rock band', 'participating'),
('Dec Rocs', 'Alternative project', 'participating'),
('Splean', 'Russian rock band', 'participating');
COMMIT;

select * from Awards;
-- --------------------------
-- Albums
-- --------------------------
INSERT INTO Albums (musician_id, title, release_date, link, pic_link) VALUES
(1, 'Photo with a Star', TO_DATE('2025-01-15','YYYY-MM-DD'), 'https://open.spotify.com/album/3pNY656sagz7e5RxbzsVLn?si=6DTteWr1QOqFMz4dJuE8dQ', '/img/DBimg/PhotoWithAStar.jpg'),
(2, 'OK Computer', TO_DATE('1997-05-21','YYYY-MM-DD'), 'https://open.spotify.com/album/6dVIqQ8qmQ5GBnJ9shOYGE?si=zDeSR0VRQ0eBRxhZKLogMQ', '/img/DBimg/OKComputer.jpg'),
(2, 'In Rainbows', TO_DATE('2007-10-10','YYYY-MM-DD'), 'https://open.spotify.com/album/5vkqYmiPBYLaalcmjujWxK?si=QP6JFM9eTNejDEnB2jLO4Q', '/img/DBimg/InRainbows.png'),
(3, 'New Album', TO_DATE('2025-03-01','YYYY-MM-DD'), 'https://open.spotify.com/album/5O0lvSqOB9IEmHyKsYppAn?si=WCdqcnKXQLiV9voG1JniNQ', '/img/DBimg/NewAlbum.jpg'),
(4, 'ARE U COMING?', TO_DATE('2024-11-20','YYYY-MM-DD'), 'https://open.spotify.com/album/2kcJ3TxBhSwmki0QWFXUz8?si=-bJVs7_HRo-kbMBLrSgEjA', '/img/DBimg/RushAreYouComing.jpg'),
(5, 'another night', TO_DATE('2023-07-12','YYYY-MM-DD'), 'https://open.spotify.com/album/59vg69fpe2kjUepVKZG2MX?si=aP5_z5gkRDGh_VXdGD6mEA', '/img/DBimg/AnotherNight.jpg'),
(6, 'A Real Good Person', TO_DATE('2022-08-30','YYYY-MM-DD'), 'https://open.spotify.com/album/5mDuvmrgSQYH5m54GoM5GC?si=ddA0r_B1QnSZf28Usk0_kw', '/img/DBimg/ARealGoodPersonInARealBadPlace.jpg'),
(7, 'Vira and Maina', TO_DATE('2021-12-15','YYYY-MM-DD'), 'https://open.spotify.com/album/1sSxGRLLiCqwW1zvBCmpph?si=Kmk0Z6c-Qwazaxd0-jfCeQ', '/img/DBimg/ViraAndMaina.jpg');

COMMIT;

select * from albums;

-- --------------------------
-- Music tracks
-- --------------------------
INSERT INTO Music (album_id, title) VALUES
(1, 'Photo with a Star'),
(2, 'Paranoid Android'),
(2, 'Karma Police'),
(2, 'Exit Music (For A Film)'),
(2, 'Let Down'),
(2, 'Lucky'),
(3, '15 Step'),
(3, 'All I Need'),
(3, 'Jigsaw Falling Into Place'),
(3, 'Videotape'),
(3, 'Nude'),
(4, 'Is The Universe Endless?'),
(4, 'Vietnam'),
(4, 'We Want To Dance'),
(5, 'HONEY'),
(5, 'VALENTINE'),
(5, 'OFF MY FACE'),
(5, 'THE DRIVER'),
(5, 'GOSSIP'),
(5, 'BLA BLA BLA'),
(5, 'GASOLINE'),
(6, 'another night'),
(6, 'stop me'),
(6, '00:13'),
(6, 'messed world'),
(6, 'days melted'),
(6, 'how''s it going?'),
(6, '04:58'),
(6, 'bubblegum'),
(7, 'Tick'),
(7, 'Why Why Why'),
(7, 'Imaginary Friends'),
(7, 'Born to Lose'),
(7, 'break break break'),
(7, 'Don''t Hurt Me'),
(8, 'Ghost'),
(8, 'Jean'),
(8, 'Phase'),
(8, 'Deja Vu'),
(8, 'Nightmares'),
(8, 'Cafe');
COMMIT;



-- --------------------------
-- Nominants
-- --------------------------
-- SHIRASAGI (all albums)
INSERT INTO Nominants (award_id, album_id) VALUES (1,1);
INSERT INTO Nominants (award_id, album_id) VALUES (1,2);
INSERT INTO Nominants (award_id, album_id) VALUES (1,3);
INSERT INTO Nominants (award_id, album_id) VALUES (1,4);
INSERT INTO Nominants (award_id, album_id) VALUES (1,5);
INSERT INTO Nominants (award_id, album_id) VALUES (1,6);
INSERT INTO Nominants (award_id, album_id) VALUES (1,7);
INSERT INTO Nominants (award_id, album_id) VALUES (1,8);

-- RAVE
INSERT INTO Nominants (award_id, album_id) VALUES (2,1);

-- GOOD O'TIMES
INSERT INTO Nominants (award_id, album_id) VALUES (3,2);
INSERT INTO Nominants (award_id, album_id) VALUES (3,3);
INSERT INTO Nominants (award_id, album_id) VALUES (3,8);

-- MINDSET
INSERT INTO Nominants (award_id, album_id) VALUES (4,2);
INSERT INTO Nominants (award_id, album_id) VALUES (4,3);
INSERT INTO Nominants (award_id, album_id) VALUES (4,6);
INSERT INTO Nominants (award_id, album_id) VALUES (4,7);

-- STYLE
INSERT INTO Nominants (award_id, album_id) VALUES (5,1);
INSERT INTO Nominants (award_id, album_id) VALUES (5,4);
COMMIT;


select * from Nominants;
--=============
UPDATE Albums
SET pic_link = '/img/DBimg/NewAlbum.jpg'
WHERE album_id = 4;

COMMIT;

SELECT * FROM MUSIC;

BEGIN
    pkg_admin.add_manager(
        p_username => 'manager',
        p_gmail   => 'man@gmail.com',
        p_password => 'manager'
    );
END;
/

commit;

select * from Musicians;