create schema if not exists safari_connect;

set search_path to safari_connect;

drop table safari_connect_dirty;

select * from safari_connect_dirty;

-- The Cleaning bit
-- We begin with booking_id that is duplicates
select booking_id from safari_connect_dirty group by booking_id having count (booking_id) > 1;

--We ensure that that booking id is actually a duplicate not different records
select ctid, * from safari_connect_dirty where booking_id ='BK0005';

/*we delete with a unique code ctid which gives exact coordinates 
of where data is sitted in the disk. They could be duplicates but are stored
in different slots inthe disk

*ctid - current tuple identifier*/

--deleting one of the records.
-- This mehod 
delete from safari_connect_dirty u1 
using safari_connect_dirty u2 
where u1.booking_id = u2.booking_id
and u1.ctid > u2.ctid;

-- Lets see the way the names appear
select * from safari_connect_dirty limit 70;

select initcap(TRIM(passenger_name)) from safari_connect_dirty;

-- updating the name to appear without spaces and without 
update safari_connect_dirty
set passenger_name = initcap(TRIM(passenger_name));

-- lets see the way phone numbers lok like
select passenger_phone from safari_connect_dirty;


--lets visualize how a clean phone number will look like
select passenger_phone,
regexp_replace(passenger_phone, '[^0-9]', '','g'), 
concat('0', right(regexp_replace(passenger_phone, '[^0-9]', '','g'),9))
from safari_connect_dirty;

-- replace the dirty numbers with the clean ones
update safari_connect_dirty
set passenger_phone = concat('0', right(regexp_replace(passenger_phone, '[^0-9]', '','g'),9));

--Lets see how the passanger gender will look like
select distinct passenger_gender from safari_connect_dirty;

-- First lets correct the cases
update safari_connect_dirty
set passenger_gender = initcap(passenger_gender);

-- We then replace M with male and F with female
update safari_connect_dirty
set passenger_gender= case
	when passenger_gender = 'M' then 'Male'
	when passenger_gender = 'F' then 'Female'
	else passenger_gender
end;

--lets see passenger_city and change to title case
select distinct passenger_city from safari_connect_dirty;

update safari_connect_dirty
set passenger_city = initcap(passenger_city);

--There's not much to correct in terms of route_code
select distinct route_code from safari_connect_dirty order by route_code desc;

--update route_to and route_from to title case
update safari_connect_dirty
set 
	route_to = initcap(route_to),
	route_from = initcap(route_from);

select distinct route_from from safari_connect_dirty;

select vehicle_plate, 
case 
	when vehicle_plate ~ '^K[A-Z]{2} [0-9]{3}[A-Z]{1}$' then 'True'
	else 'false'
end as compliant_check
from safari_connect_dirty;

-- This line here shows that all the number plates are compliant
select * from safari_connect_dirty
where vehicle_plate !~ '^K[A-Z]{2} [0-9]{3}[A-Z]{1}$';

--see the vehicle types
select distinct vehicle_type from safari_connect_dirty;

update safari_connect_dirty
set vehicle_type =initcap(vehicle_type);

--change the drivers name to title case

update safari_connect_dirty
set driver_name = initcap(TRIM(driver_name));


--altering the columns data type
alter table safari_connect_dirty
alter column driver_rating type numeric
using driver_rating::numeric;


-- cleaning up the date
/*
 * The date types appear in several methods
 * dd/mm/yyyy
 * dd-mm-yyyy
 * 
 * mm-dd-yyyy
 * mm/dd/yyy
 * 
 * yyyy-mm-dd
 * yyyy/mm/dd
 * 
 * dd-mm-yy
 * 
 * we need to make a case for each and convert them to date
 * */

--We will create a new column

alter table safari_connect_dirty
add column new_date date;

SET datestyle = 'ISO, MDY';

update safari_connect_dirty
set new_date =
case
	when departure_date ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then to_date(departure_date, 'YYYY-MM-DD')
	when departure_date ~ '^[0-9]{4}/[0-9]{2}/[0-9]{2}$' then to_date(departure_date, 'YYYY/MM/DD')
	when departure_date ~ '^[0-9]{2}-(1[3-9]|[2][0-9]|[3][0-1])-[0-9]{4}$' then to_date(departure_date, 'MM-DD-YYYY')
	when departure_date ~ '^[0-9]{2}/(1[3-9]|[2][0-9]|[3][0-1])/[0-9]{4}$' then to_date(departure_date, 'MM/DD/YYYY')
	when departure_date ~ '^[0-9]{2}/[0-9]{2}/[0-9]{4}$' then to_date(departure_date, 'DD/MM/YYYY')
	when departure_date ~ '^[0-9]{2}-[0-9]{2}-[0-9]{4}$' then to_date(departure_date, 'DD-MM-YYYY')
	when departure_date ~ '^[0-9]{2}-[0-9]{2}-[0-9]{2}$' then to_date(departure_date, 'DD-MM-YY')
	else null
end;

-- We can confirm that the date is now okey
select departure_date, new_date from safari_connect_dirty;


-- update the previous date
update safari_connect_dirty
set departure_date = new_date;

-- drop the new date
alter table safari_connect_dirty
drop column new_date;

-- testing the new time format
select departure_time, to_char(departure_time::time, 'HH24:MI') 
from safari_connect_dirty;

--lets update time
update safari_connect_dirty
set departure_time = to_char(departure_time::time, 'HH24:MI');

--ensuring that seat class is either economy or business

select distinct seat_class from safari_connect_dirty;

--first update is to ensure that casing is not the problem so you have less cases 
-- to compare to
update safari_connect_dirty
set seat_class = initcap(seat_class);

--Final update to ensure all scenarios are inline with our criteria
update safari_connect_dirty
set seat_class = case
	when seat_class = 'Business Class' then 'Business'
	when seat_class = 'Economy Class' then 'Economy'
	when seat_class = 'Bus' then 'Business'
	when seat_class = 'Eco' then 'Economy'
	else seat_class
end
;

--ensuring all seats booked are positive integers
update safari_connect_dirty
set seats_booked= abs(seats_booked);

-- converting fare_per_seat to numeric
select distinct fare_per_seat from safari_connect_dirty;

update safari_connect_dirty
set fare_per_seat = regexp_replace(fare_per_seat, '[^0-9]','','g');


alter table safari_connect_dirty
alter column fare_per_seat type numeric
using fare_per_seat::numeric;

--total fare
update safari_connect_dirty
set total_fare = (seats_booked*fare_per_seat);

alter table safari_connect_dirty
alter column total_fare type numeric
using total_fare::numeric;


--payment method
-- Change all to lower case
update safari_connect_dirty
set payment_method = initcap(payment_method);

select distinct payment_method from safari_connect_dirty;

update safari_connect_dirty
set payment_method= case
	when payment_method = 'M-pesa' then 'M-Pesa'
	else payment_method
end;

--booking status
select distinct booking_status from safari_connect_dirty;

update safari_connect_dirty
set booking_status = initcap(TRIM(booking_status));

select distinct trip_rating from safari_connect_dirty;

-- ensure that rating is (1-5)
begin;

update safari_connect_dirty
set 
	trip_rating = null where trip_rating not in (1,2,3,4,5);
	select distinct trip_rating from safari_connect_dirty;

commit ;

-- We are then going to be adding constraints to make sure
-- that the data that come in after that remains unadulterated


-- ensure rating is between 1 & 5
alter table safari_connect_dirty
add constraint ratin_constraint
check(trip_rating in (1,2,3,4,5,null));

alter table safari_connect_dirty
add constraint book_status_checker
check(booking_status in('Completed','Cancelled', 'No Show'));

alter table safari_connect_dirty
add constraint seats_checker
check(seats_booked >=0);

alter table safari_connect_dirty
add constraint seatClassChecker
check(seat_class in('Economy', 'Business'));

alter table safari_connect_dirty
add constraint vehicleTypeChecker
check(vehicle_type in ('Bus', 'Matatu', 'Minibus'));


-- i didnt know that making a primary key is also a constraint haha
--This will make the column unique and add a primary key to the mix
alter table safari_connect_dirty
add constraint booking_id_prime primary key (booking_id);













select * from safari_connect_dirty;





