CREATE DATABASE Project_database_MMF;

USE Project_database_MMF;


-- Таблица "Студенты"
CREATE TABLE Students (
  student_id INT PRIMARY KEY AUTO_INCREMENT,
  full_name VARCHAR(255) NOT NULL,
  course INT NOT NULL CHECK (course BETWEEN 1 AND 6),
  group_num INT NOT NULL CHECK (group_num BETWEEN 1 AND 10),
  test_retakes INT DEFAULT 0,   											-- количество пересдач зачётов (несданных)
  history_test_retakes INT DEFAULT 0,										-- количество пересдач зачётов (несданных за все время)
  access BOOL DEFAULT TRUE,													-- допуск к экзаменам	
  exam_retakes INT DEFAULT 0,												-- количество пересдач экзаменов
  history_exam_retakes INT DEFAULT 0,										-- количество пересдач экзаменов (несданных за все время)
  expulsion BOOL DEFAULT FALSE,												-- отчислен или нет
  date_of_admission DATE NOT NULL
);


-- Таблица "Преподаватели"
CREATE TABLE Teachers (
  teacher_id INT PRIMARY KEY AUTO_INCREMENT,
  full_name VARCHAR(255) NOT NULL,
  degree VARCHAR(255) NOT NULL												-- "звание" преподавателя			
);


-- Таблица "Учебные предметы"
CREATE TABLE Subjects (
  subject_id INT PRIMARY KEY AUTO_INCREMENT,
  subject_name VARCHAR(255) NOT NULL,
  has_test BOOL NOT NULL,          											-- наличие зачёта  
  has_exam BOOL NOT NULL           											-- наличие экзамена
);


-- Таблица "Пара"
CREATE TABLE Lecture (
  lecture_id INT PRIMARY KEY AUTO_INCREMENT,
  date_time DATETIME NOT NULL,
  teacher_id INT NOT NULL,
  subject_id INT NOT NULL,
  group_num INT NOT NULL CHECK (group_num BETWEEN 1 AND 10),
  course INT NOT NULL CHECK (course BETWEEN 1 AND 6),
  FOREIGN KEY (teacher_id) REFERENCES Teachers(teacher_id),
  FOREIGN KEY (subject_id) REFERENCES Subjects(subject_id)
);


-- Таблица "Посещаемость"
CREATE TABLE Attendance (
  attendance_id INT PRIMARY KEY AUTO_INCREMENT,
  student_id INT NOT NULL,
  lecture_id INT NOT NULL,
  present BOOL NOT NULL,													-- наличие студента на паре или нет
  FOREIGN KEY (student_id) REFERENCES Students(student_id),
  FOREIGN KEY (lecture_id) REFERENCES Lecture(lecture_id)
);


-- Таблица "Успеваемость за пары" (все оценки)
CREATE TABLE Performance (
  performance_id INT PRIMARY KEY AUTO_INCREMENT,
  student_id INT NOT NULL,
  lecture_id INT NOT NULL,
  grade INT CHECK (grade BETWEEN 1 AND 10) DEFAULT NULL,
  FOREIGN KEY (student_id) REFERENCES Students(student_id),
  FOREIGN KEY (lecture_id) REFERENCES Lecture(lecture_id)
);


-- Таблица "Окончательная успеваемость за предмет"
CREATE TABLE Overall_Performance (
  overall_performance_id INT PRIMARY KEY AUTO_INCREMENT,
  performance_id INT NOT NULL,
  student_id INT NOT NULL,
  subject_id INT NOT NULL,
  grade_by_lecture INT DEFAULT NULL CHECK (grade_by_lecture BETWEEN 1 AND 10),				
  exam_grade INT DEFAULT NULL CHECK (exam_grade BETWEEN 4 AND 10),							
  rating_grade INT DEFAULT NULL CHECK (rating_grade BETWEEN 1 AND 10),						
  test BOOL default NULL,																
  exam BOOL default NULL,																
  exam_coefficient_value FLOAT default  NULL,
  lecture_coefficient_value FLOAT default  NULL,
  FOREIGN KEY (performance_id) REFERENCES Performance(performance_id),
  FOREIGN KEY (student_id) REFERENCES Students(student_id),
  FOREIGN KEY (subject_id) REFERENCES Subjects(subject_id)
);


-- Обновление значения test_retakes и history_retakes в таблице Students для подсчёта пересдач по зачётам
DELIMITER //
CREATE TRIGGER update_test_retakes
AFTER UPDATE ON Overall_Performance
FOR EACH ROW
BEGIN
  DECLARE retakes INT;
  DECLARE hs_retakes INT;
  
  SELECT test_retakes, history_test_retakes INTO retakes, hs_retakes
  FROM Students
  WHERE student_id = NEW.student_id;
  
  IF NEW.test = FALSE THEN
    SET retakes = retakes + 1;
    SET hs_retakes = hs_retakes + 1;
    UPDATE Students SET test_retakes = retakes, history_test_retakes = hs_retakes WHERE student_id = NEW.student_id;
  ELSEIF NEW.test = TRUE AND OLD.test = FALSE THEN
    SET retakes = retakes - 1;
    UPDATE Students SET test_retakes = retakes WHERE student_id = NEW.student_id;
  END IF;
END//
DELIMITER ;


-- Обновление значения exam_retakes и history_exam_retakes в таблице Students для подсчёта пересдач по экзаменам
DELIMITER //
CREATE TRIGGER update_exam_retakes
AFTER UPDATE ON Overall_Performance
FOR EACH ROW
BEGIN
  DECLARE ex_retakes INT;
  DECLARE hs_ex_retakes INT;
  
  SELECT exam_retakes, history_exam_retakes INTO ex_retakes, hs_ex_retakes
  FROM Students
  WHERE student_id = NEW.student_id;
  
  IF NEW.exam = FALSE THEN
    SET ex_retakes = ex_retakes + 1;
    SET hs_ex_retakes =  hs_ex_retakes + 1;
    UPDATE Students SET exam_retakes = ex_retakes, history_exam_retakes = hs_ex_retakes WHERE student_id = NEW.student_id;
  ELSEIF NEW.exam = TRUE AND OLD.exam = FALSE THEN
    SET ex_retakes = ex_retakes - 1;
    UPDATE Students SET exam_retakes = ex_retakes WHERE student_id = NEW.student_id;
  END IF;
END//
DELIMITER ;


-- Обновление значений access и expulsion в таблице Students для допуска студента к экзамену
DELIMITER //
CREATE TRIGGER check_exam_access
BEFORE INSERT ON Overall_Performance
FOR EACH ROW
BEGIN
  DECLARE retakes INT;
  DECLARE hs_retakes INT;
  
  SELECT test_retakes, history_test_retakes INTO retakes, hs_retakes
  FROM Students
  WHERE student_id = NEW.student_id;
  
  IF retakes >= 1 AND retakes < 3 AND hs_retakes < 3 THEN
    UPDATE Students SET access = FALSE WHERE student_id = NEW.student_id;
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Доступ запрещен. У студента имеется пересдача(-и).';
  ELSEIF hs_retakes >= 3 THEN
    UPDATE Students SET expulsion = TRUE, access = FALSE  WHERE student_id = NEW.student_id;
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Студент отчислен. Превышено количество пересдач.';
  END IF;
END//
DELIMITER ;


-- Обновление значений expulsion в таблице Students для допуска студента к "учёбе"
DELIMITER //
CREATE TRIGGER check_exam
BEFORE INSERT ON Overall_Performance
FOR EACH ROW
BEGIN
  DECLARE ex_retakes INT;
  DECLARE hs_ex_retakes INT;
  
  SELECT exam_retakes, history_exam_retakes INTO ex_retakes, hs_ex_retakes
  FROM Students
  WHERE student_id = NEW.student_id;
  
  IF ex_retakes >= 1 AND ex_retakes < 3 AND hs_ex_retakes < 3 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'У студента имеется пересдача(-и).';
  ELSEIF hs_ex_retakes >= 3 THEN
    UPDATE Students SET expulsion = TRUE WHERE student_id = NEW.student_id;
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Студент отчислен. Превышено количество пересдач.';
  END IF;
END//
DELIMITER ;


-- Считается текущая оценка за успеваемость(grade_by_lecture) в таблице Overall_Performance
DELIMITER //
CREATE TRIGGER update_grade_by_lecture
AFTER INSERT ON Performance
FOR EACH ROW
BEGIN
  DECLARE avg_grade FLOAT;
  
  SELECT AVG(grade) INTO avg_grade
  FROM Performance
  WHERE student_id = NEW.student_id AND lecture_id IN (
    SELECT lecture_id
    FROM Lecture
    WHERE subject_id = NEW.subject_id
  );
  
  IF avg_grade IS NOT NULL THEN
    IF avg_grade - FLOOR(avg_grade) < 0.5 THEN
      SET avg_grade = FLOOR(avg_grade);
    ELSE
      SET avg_grade = CEILING(avg_grade);
    END IF;    
    UPDATE Overall_Performance SET grade_by_lecture = avg_grade WHERE performance_id = NEW.performance_id;
  END IF;
END;
DELIMITER ;


-- Считается рейтинговая оценка за предмет(rating_grade) в таблице Overall_Performance
DELIMITER //
CREATE TRIGGER calculate_rating_grade
BEFORE INSERT ON Overall_Performance
FOR EACH ROW
BEGIN
  DECLARE grade INT;
  DECLARE ex_grade INT;
  DECLARE rg_grade INT;
  DECLARE exam_coefficient FLOAT;
  DECLARE lecture_coefficient FLOAT;
  
  SELECT grade_by_lecture, exam_grade, exam_coefficient_value, lecture_coefficient_value  
  INTO grade, ex_grade, exam_coefficient, lecture_coefficient
  FROM Overall_Performance
  WHERE student_id = NEW.student_id AND subject_id = NEW.subject_id;
  
  IF grade IS NOT NULL AND ex_grade IS NOT NULL THEN
	SET rg_grade = (grade * lecture_coefficient) + (ex_grade * exam_coefficient);
  
	IF rg_grade - FLOOR(rg_grade) < 0.5 THEN
		SET rg_grade = FLOOR(rg_grade);
	ELSE
		SET rg_grade = CEILING(rg_grade);
	END IF;
	UPDATE Overall_Performance SET rating_grade = rg_grade WHERE student_id = NEW.student_id AND subject_id = NEW.subject_id;
  END IF;
END//
DELIMITER ;

#DROP DATABASE Project_database_MMF;