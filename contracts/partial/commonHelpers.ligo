[@inline] function require(
  const param           : bool;
  const error           : string)
                        : unit is
  assert_with_error(param, error)

[@inline] function check_permission(
  const address_        : address;
  const error           : string)
                        : unit is
  require(Tezos.sender = address_, error)

[@inline] function require_none(
  const param           : option(_a);
  const error           : string)
                        : unit is
  case param of
  | Some(_) -> failwith(error)
  | None -> unit
  end;

[@inline] function unwrap_or(
  const param           : option(_a);
  const default         : _a)
                        : _a is
  case param of
  | Some(instance) -> instance
  | None -> default
  end;

[@inline] function unwrap(
  const param           : option(_a);
  const error           : string)
                        : _a is
  case param of
  | Some(instance) -> instance
  | None -> failwith(error)
  end;

[@inline] function get_nat_or_fail(
  const value           : int;
  const error           : string)
                        : nat is
  case is_nat(value) of
  | Some(natural) -> natural
  | None -> (failwith(error): nat)
  end;

[@inline] function check_deadline(
  const exp             : timestamp)
                        : unit is
  require(exp >= Tezos.now, Errors.YToken.deadlineReached);

[@inline] function ceil_div(
  const numerator       : nat;
  const denominator     : nat)
                        : nat is
  case ediv(numerator, denominator) of
    Some(result) -> if result.1 > 0n
      then result.0 + 1n
      else result.0
  | None -> failwith(Errors.Math.ceilDivision)
  end;
