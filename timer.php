<?php

// turn off all error reporting
error_reporting(0);

$format = 'Y-m-d H:i:s';
$date = date('Y-m-d') . ' ';

$times = array();
$times[] = array('start' => $date . '02:00', 'end' => $date . '04:00');
// $times[] = array('start' => $date . '04:05', 'end' => $date . '05:00');
$times[] = array('start' => $date . '04:00', 'end' => $date . '06:00');
//$times[] = array('start' => $date . '01:00', 'end' => $date . '11:00');
$times[] = array('start' => $date . '06:00', 'end' => $date . '08:00');

$times[] = array('start' => $date . '12:00', 'end' => $date . '14:00');
// $times[] = array('start' => $date . '14:05', 'end' => $date . '15:00');
$times[] = array('start' => $date . '14:00', 'end' => $date . '16:00');
//$times[] = array('start' => $date . '11:00', 'end' => $date . '22:00');
$times[] = array('start' => $date . '16:00', 'end' => $date . '18:00');

//$times[] = array('start' => $date . '02:00', 'end' => $date . '11:59');

$output = consolidateHours($times);
echo "*******************************\n";
var_export($output);

function consolidateHours($times) {
  // sort incoming time entries
  usort($times, function($a, $b) {
    return strtotime($a['start']) - strtotime($b['start']);
  });

  echo "INPUT " . var_export($times, true) . "\n";
  global $format;

  $output = array();
  $lastStart = 0;
  $lastEnd = 0;

  foreach ($times as $time) {
    $start = strtotime($time['start']);
    $end = strtotime($time['end']);

    if (!$lastStart && !$lastEnd) {
      // we don't have entries yet, save current values
      $lastStart = $start;
      $lastEnd = $end;
    } else if ($start >= $lastStart && $start <= $lastEnd && $end >= $lastEnd) {
      // start date falls in the middle of the previous range, extend end time to new end time
      $lastEnd = $end;
    } else if ($end >= $lastStart && $end <= $lastEnd && $start <= $lastStart) {
      // end date falls in the middle of the previous range, use new start time
      $lastStart = $start;
    } else if ($start <= $lastStart && $end >= $lastEnd) {
      // start and end date extend beyond previous range, extend both
      $lastStart = $start;
      $lastEnd = $end;
    } else if ($start >= $lastStart && $end <= $lastEnd) {
      // start and end date fall in between previous range, don't do anything
    } else {
      $output[] = array('start' => date($format, $lastStart), 'end' => date($format, $lastEnd));
      $lastStart = $start;
      $lastEnd = $end;
    }
  }

  $output[] = array('start' => date($format, $lastStart), 'end' => date($format, $lastEnd));

  if ($times != $output) {
    $output = consolidateHours($output);
  }

  return $output;
}
