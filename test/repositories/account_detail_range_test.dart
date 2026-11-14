import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BeeDatabase db; late LocalRepository repo; late int account, other, category;
  final start=DateTime(2026,10),end=DateTime(2026,11);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db=BeeDatabase.forTesting(NativeDatabase.memory());repo=LocalRepository(db);
    await db.customStatement("INSERT INTO ledgers(id,name,currency,is_shared,my_role) VALUES(1,'个人','CNY',0,'owner'),(2,'他人共享','CNY',1,'editor'),(3,'自己共享','CNY',1,'owner')");
    account=await repo.createAccount(ledgerId:1,name:'美元账户',currency:'USD',initialBalance:1000);
    other=await repo.createAccount(ledgerId:1,name:'其他美元',currency:'USD');
    category=await repo.createCategory(name:'咖啡',kind:'expense');
  });
  tearDown(() async=>db.close());
  Future<int> tx(String type,double amount,DateTime date,{int? from,int? to,int ledger=1,bool excluded=false,String? note,double? native})=>repo.addTransaction(
    ledgerId:ledger,type:type,amount:amount,happenedAt:date,accountId:from??account,toAccountId:to,
    categoryId:category,currencyCode:'USD',nativeAmount:native??amount,note:note,excludeFromStats:excluded);

  test('范围统计、真正历史余额与共享排除一致；读操作不改原始快照',() async {
    await tx('income',50,DateTime(2026,9,30));
    await tx('income',100,DateTime(2026,10,1));
    await tx('expense',10,DateTime(2026,10,2),native:71);
    await tx('transfer',5,DateTime(2026,10,3),to:other);
    await tx('transfer',20,DateTime(2026,10,4),from:other,to:account);
    await tx('expense',7,DateTime(2026,10,5),excluded:true);
    await tx('transfer',8,DateTime(2026,10,6),to:account);
    await tx('expense',999,DateTime(2026,10,7),ledger:2);
    await tx('income',500,DateTime(2026,11,1));
    final before=await repo.getTransactionsByLedger(1);
    final totals=await repo.getAccountPeriodTotals(account,startDate:start,endExclusive:end);
    expect(totals.count,6);expect(totals.income,128);expect(totals.expense,23);
    final history=await repo.getAccountDailyBalances(account,startDate:start,endDate:DateTime(2026,10,31));
    expect(history.length,31);expect(history.first.balance,1150);expect(history.last.balance,1148);
    expect(await repo.getAccountBalance(account),1648);
    expect(await repo.getTransactionsByLedger(1),before);
  });
  test('过滤先于分页，稳定同秒排序；搜索不把百分号当通配符',() async {
    final ids=<int>[];
    await tx('expense',99,DateTime(2026,9,30));
    for(var i=0;i<6;i++){ids.add(await tx('expense',i+1,DateTime(2026,10,20),note:i==0?'100% 测试':'普通 $i'));}
    await tx('expense',199,DateTime(2026,11,1));
    final first=await repo.getAccountTransactions(account,startDate:start,endExclusive:end,limit:2);
    final second=await repo.getAccountTransactions(account,startDate:start,endExclusive:end,limit:2,offset:2);
    expect(first.map((x)=>x.id),ids.reversed.take(2));expect(second.map((x)=>x.id),ids.reversed.skip(2).take(2));
    final query=await repo.getAccountTransactions(account,startDate:start,endExclusive:end,query:'%');expect(query.single.id,ids.first);
    final asc=await repo.getAccountTransactions(account,startDate:start,endExclusive:end,ascending:true,orderByAmount:true);
    expect(asc.map((x)=>x.amount),[1,2,3,4,5,6]);
  });
  test('分类分布遵循时间范围，原币金额不被本位币快照替换',() async {
    await tx('expense',12,DateTime(2026,10,20),native:85.2);
    await tx('expense',50,DateTime(2026,9,20));
    final stats=await repo.getAccountCategoryStats(account,type:'expense',startDate:start,endExclusive:end);
    expect(stats.single.total,12);
    final row=(await repo.getAccountTransactions(account,startDate:start,endExclusive:end)).single;
    expect(row.amount,12);expect(row.nativeAmount,85.2);expect(row.currencyCode,'USD');
  });
}
