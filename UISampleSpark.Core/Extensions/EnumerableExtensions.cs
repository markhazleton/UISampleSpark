
namespace UISampleSpark.Core.Extensions;

public static class EnumerableExtensions
{
    public enum MinMaxOption
    {
        Minimum,
        Maximum,
        First,
        Last,
        Mean
    }

    public static T? SelectElementByOption<T, TKey>(this IEnumerable<T>? sequence, Func<T, TKey> keySelector, MinMaxOption option = MinMaxOption.Minimum)
        where T : class
        where TKey : IComparable<TKey>
    {
        ArgumentNullException.ThrowIfNull(keySelector);

        if (sequence == null || !sequence.Any())
            return default;

        switch (option)
        {
            case MinMaxOption.Minimum:
                return sequence
                    .Select(obj => Tuple.Create(obj, keySelector(obj)))
                    .Aggregate(default(Tuple<T, TKey>),
                        (best, cur) => best == null || cur.Item2.CompareTo(best.Item2) < 0 ? cur : best)!.Item1;

            case MinMaxOption.Maximum:
                return sequence
                    .Select(obj => Tuple.Create(obj, keySelector(obj)))
                    .Aggregate(default(Tuple<T, TKey>),
                        (best, cur) => best == null || cur.Item2.CompareTo(best.Item2) > 0 ? cur : best)!.Item1;

            case MinMaxOption.First:
                return sequence.FirstOrDefault();

            case MinMaxOption.Last:
                return sequence.LastOrDefault();

            case MinMaxOption.Mean:
                double sum = 0;
                int count = 0;

                foreach (T element in sequence)
                {
                    TKey key = keySelector(element);
                    if (key is IConvertible convertible)
                    {
                        sum += Convert.ToDouble(convertible);
                        count++;
                    }
                }

                if (count > 0)
                {
                    double mean = sum / count;
                    return sequence
                        .OrderBy(element => Math.Abs(Convert.ToDouble(keySelector(element)) - mean))
                        .FirstOrDefault();
                }

                return default;

            default:
                return default;
        }
    }





}
